import type {
  Meta,
  StoryObj
} from "@storybook/react-vite";

import {
  AudienceShell,
  Surface
} from "@akal-budi/ui";

const meta = {
  title: "Primitives/Surface",
  component: Surface,
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
    style: {
      maxWidth: "28rem",
      padding: "2rem"
    },
    children: "Permukaan kandungan Akal Budi"
  }
} satisfies Meta<typeof Surface>;

export default meta;

type Story = StoryObj<typeof meta>;

export const Raised: Story = {};

export const Flat: Story = {
  args: {
    elevation: "flat"
  }
};
