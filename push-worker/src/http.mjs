// Keep the signal alive after headers arrive so stalled response bodies are
// bounded too. Do not retry here: some requests perform writes or send pushes.
export function fetchWithTimeout(input, init = {}, timeoutMs = 15_000) {
  const deadline = AbortSignal.timeout(timeoutMs);
  const signal = init.signal ? AbortSignal.any([init.signal, deadline]) : deadline;
  return fetch(input, { ...init, signal });
}
