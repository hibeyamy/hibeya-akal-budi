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
  if(!t?.id) throw new Error("Learner/Journey story not found");
  return t.id;
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
  const results=await new AxeBuilder({page}).include('[data-testid="activity-player"]').analyze();
  expect(results.violations,JSON.stringify(results.violations,null,2)).toEqual([]);
});

test("choice keyboard semantics, focus indicator and feedback live region are valid",async({page})=>{
  await openActivity(page);
  const feedback=page.getByTestId("learner-feedback");
  await expect(feedback).toHaveAttribute("aria-live","polite");
  await expect(feedback).toHaveAttribute("aria-atomic","true");

  const choices=page.getByTestId("learner-choice");
  const first=choices.first();
  await first.focus();
  await expect(first).toBeFocused();

  const focusStyle=await first.evaluate(el=>{
    const s=getComputedStyle(el);
    return {outline:s.outlineStyle,boxShadow:s.boxShadow};
  });
  expect(
    focusStyle.outline!=="none" ||
    (focusStyle.boxShadow!=="none" && focusStyle.boxShadow!=="")
  ).toBeTruthy();

  await page.keyboard.press("Enter");
  await expect(page.getByTestId("activity-player")).toHaveAttribute("data-answer-count","1");
  await expect.poll(()=>feedback.getAttribute("data-feedback-state")).toMatch(/^(correct|incorrect)$/);

  const icon=page.getByTestId("learner-choice-state-icon");
  await expect(icon).toHaveAttribute("aria-hidden","true");
  await expect(feedback).not.toHaveText("");
});

test("completion disables choices for keyboard and pointer interaction",async({page})=>{
  let candidate=0;
  while(true){
    await openActivity(page);
    const choices=page.getByTestId("learner-choice");
    if(candidate>=await choices.count()) throw new Error("No correct option exposed by production mechanic");
    const player=page.getByTestId("activity-player");
    await choices.nth(candidate).focus();
    await page.keyboard.press("Space");
    await expect(player).toHaveAttribute("data-answer-count","1");
    await expect.poll(()=>page.getByTestId("learner-feedback").getAttribute("data-feedback-state")).toMatch(/^(correct|incorrect)$/);
    if(await player.getAttribute("data-activity-state")==="completed"){
      await expect(page.getByTestId("learner-completion")).toBeVisible();
      for(let i=0;i<await choices.count();i++) await expect(choices.nth(i)).toBeDisabled();
      const before=await player.getAttribute("data-answer-count");
      await page.keyboard.press("Enter");
      await expect(player).toHaveAttribute("data-answer-count",before!);
      return;
    }
    candidate++;
  }
});

test("learner choices suppress transform/transition under reduced motion",async({page})=>{
  await page.emulateMedia({reducedMotion:"reduce"});
  await openActivity(page);
  const style=await page.getByTestId("learner-choice").first().evaluate(el=>{
    const s=getComputedStyle(el);
    return {duration:s.transitionDuration};
  });
  expect(style.duration).toBe("0s");
});
