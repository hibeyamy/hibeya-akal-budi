export interface NetworkStatus {
  online: boolean;
}

export function getNetworkStatus(): NetworkStatus {
  return {
    online: navigator.onLine
  };
}

export function subscribeToNetworkStatus(
  listener: (status: NetworkStatus) => void
): () => void {
  function handleOnline() {
    listener({ online: true });
  }

  function handleOffline() {
    listener({ online: false });
  }

  window.addEventListener("online", handleOnline);
  window.addEventListener("offline", handleOffline);

  return () => {
    window.removeEventListener("online", handleOnline);
    window.removeEventListener("offline", handleOffline);
  };
}
