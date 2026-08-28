import "../../learner-web/src/index.css";
import type {
  Preview
} from "@storybook/react-vite";

import "../../../packages/design-system/src/tokens.css";
import "@akal-budi/ui/styles.css";

const preview: Preview = {
  parameters: {
    controls: {
      expanded: true
    },
    a11y: {
      test: "error"
    }
  }
};

export default preview;
