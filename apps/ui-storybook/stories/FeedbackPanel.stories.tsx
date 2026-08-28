import type {
  Meta,
  StoryObj
} from "@storybook/react-vite";

import {
  AudienceShell,
  FeedbackPanel
} from "@akal-budi/ui";

const meta = {
  title: "Primitives/FeedbackPanel",
  component: FeedbackPanel,
  decorators: [
    Story => (
      <AudienceShell
        audience="learner"
        style={{ padding: "2rem" }}
      >
        <Story />
      </AudienceShell>
    )
  ],
  args: {
    children: "Cuba lagi. Tengok dengan teliti."
  }
} satisfies Meta<typeof FeedbackPanel>;

export default meta;

type Story = StoryObj<typeof meta>;

export const Gentle: Story = {};

export const Success: Story = {
  args: {
    tone: "success",
    children: "Betul. Bagus."
  }
};

export const Error: Story = {
  args: {
    tone: "error",
    children: "Aktiviti belum dapat dimuatkan."
  }
};
