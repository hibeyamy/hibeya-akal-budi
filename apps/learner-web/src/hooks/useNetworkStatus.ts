import {
  useEffect,
  useState
} from "react";

import {
  getNetworkStatus,
  subscribeToNetworkStatus
} from "@akal-budi/offline";

export function useNetworkStatus() {
  const [status, setStatus] = useState(
    getNetworkStatus
  );

  useEffect(() => {
    return subscribeToNetworkStatus(
      setStatus
    );
  }, []);

  return status;
}
