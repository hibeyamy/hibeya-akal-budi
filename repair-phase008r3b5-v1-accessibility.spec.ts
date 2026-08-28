import fs from "node:fs";
import path from "node:path";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Page } from "@playwright/test";
type Entry={id?:string;title?:string;name?:string;type?:string;importPath?:string};
function storyId(){
 const p=path.resolve(process.cwd(),"apps","ui-storybook","storybook-static","index.json");
 const x=JSON.parse(fs.readFileSync(p,"utf8")) as {entries?:Record<string,Entry>};
 const c=Object.values(x.entries??{}).filter(e=>e.title==="Learner/Journey"||String(e.importPath??"").includes("LearnerJourney.stories"));
 const t=c.find(e=>e.type==="story"&&e.name==="Default")??c.find(e=>e.type==="story");
 if(!t?.id)throw new Error("Learner/Journey story not found");return t.id;
}
const id=storyId();
async function openActivity(page:Page){
 await page.goto(`/iframe.html?id=${encodeURIComponent(id)}&viewMode=story`,{waitUntil:"networkidle"});
 await page.getByRole("button",{name:"Lihat aktiviti"}).click();
 await page.getByRole("button",{name:/Kenal warna merah/}).click();
 await expect(page.getByTestId("activity-player")).toHaveAttribute("data-activity-state","idle");
}
test("learner activity satisfies automated accessibility baseline",async({page})=>{
 await openActivity(page);
 const r=await new AxeBuilder({page}).include('[data-testid="activity-player"]').analyze();
 expect(r.violations,JSON.stringify(r.violations,null,2)).toEqual([]);
});
test("keyboard focus, activation and feedback live region are valid",async({page})=>{
 await openActivity(page);
 const feedback=page.getByTestId("learner-feedback");
 await expect(feedback).toHaveAttribute("aria-live","polite");
 await expect(feedback).toHaveAttribute("aria-atomic","true");
 const choices=page.getByTestId("learner-choice");
 // Use genuine keyboard traversal; programmatic .focus() does not reliably activate :focus-visible.
 for(let i=0;i<20;i++){
   await page.keyboard.press("Tab");
   if(await choices.first().evaluate(el=>document.activeElement===el)) break;
 }
 await expect(choices.first()).toBeFocused();
 const visible=await choices.first().evaluate(el=>{
   const s=getComputedStyle(el);
   const ow=parseFloat(s.outlineWidth)||0;
   const shadows=s.boxShadow!=="none"&&s.boxShadow!=="";
   return ow>0||shadows;
 });
 expect(visible).toBe(true);
 await page.keyboard.press("Enter");
 await expect(page.getByTestId("activity-player")).toHaveAttribute("data-answer-count","1");
 await expect.poll(()=>feedback.getAttribute("data-feedback-state")).toMatch(/^(correct|incorrect)$/);
 await expect(feedback).not.toHaveText("");
});
test("completion disables choices",async({page})=>{
 let candidate=0;
 while(true){
   await openActivity(page);
   const choices=page.getByTestId("learner-choice"),player=page.getByTestId("activity-player");
   if(candidate>=await choices.count())throw new Error("No correct option exposed");
   await choices.nth(candidate).click();
   await expect(player).toHaveAttribute("data-answer-count","1");
   await expect.poll(()=>page.getByTestId("learner-feedback").getAttribute("data-feedback-state")).toMatch(/^(correct|incorrect)$/);
   if(await player.getAttribute("data-activity-state")==="completed"){
     for(let i=0;i<await choices.count();i++)await expect(choices.nth(i)).toBeDisabled();
     return;
   }
   candidate++;
 }
});
test("learner choices effectively suppress transition under reduced motion",async({page})=>{
 await page.emulateMedia({reducedMotion:"reduce"});await openActivity(page);
 const seconds=await page.getByTestId("learner-choice").first().evaluate(el=>{
   const values=getComputedStyle(el).transitionDuration.split(",").map(v=>v.trim());
   return Math.max(...values.map(v=>v.endsWith("ms")?parseFloat(v)/1000:parseFloat(v)));
 });
 // Tailwind/browser may serialise transition-none as 0.00001s; treat <=0.1ms as effectively zero.
 expect(seconds).toBeLessThanOrEqual(0.0001);
});
