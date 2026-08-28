import type {
  Meta,
  StoryObj
} from "@storybook/react-vite";

import {
  AudienceShell,
  Button
} from "@akal-budi/ui";

const meta = {
  title: "Primitives/Button",
  component: Button,
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
    children: "Aktiviti seterusnya"
  }
} satisfies Meta<typeof Button>;

export default meta;

type Story = StoryObj<typeof meta>;

export const Primary: Story = {};

export const Secondary: Story = {
  args: {
    variant: "secondary",
    children: "Mula semula"
  }
};

export const Gentle: Story = {
  args: {
    variant: "gentle",
    children: "Sambung"
  }
};

export const Disabled: Story = {
  args: {
    disabled: true,
    children: "Belum tersedia"
  }
};
