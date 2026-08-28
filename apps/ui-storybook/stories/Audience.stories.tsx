import type {
  Meta,
  StoryObj
} from "@storybook/react-vite";

import {
  AudienceShell,
  Button,
  Surface
} from "@akal-budi/ui";

const meta = {
  title: "Foundations/Audience",
  component: AudienceShell
} satisfies Meta<typeof AudienceShell>;

export default meta;

type Story = StoryObj<typeof meta>;

export const Learner: Story = {
  args: {
    audience: "learner",
    style: {
      padding: "2rem"
    },
    children: (
      <Surface style={{ padding: "2rem" }}>
        <h2>Learner</h2>
        <p>
          Large targets, low reading density, minimal motion.
        </p>
        <Button>
          Teruskan
        </Button>
      </Surface>
    )
  }
};

export const Parent: Story = {
  args: {
    audience: "parent",
    style: {
      padding: "2rem"
    },
    children: (
      <Surface style={{ padding: "2rem" }}>
        <h2>Parent</h2>
        <p>
          Higher information density with the same semantic design language.
        </p>
        <Button>
          Lihat kemajuan
        </Button>
      </Surface>
    )
  }
};
