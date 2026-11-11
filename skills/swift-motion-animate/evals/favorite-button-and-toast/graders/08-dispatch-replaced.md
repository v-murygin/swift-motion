---
type: llm
focus: trace
weight: 1
---

The DispatchQueue.main.asyncAfter auto-dismiss is replaced or made cancellable (e.g. a .task(id:) with Task.sleep), so rapid re-taps don't hide a newer toast early; or the response explicitly addresses this race.
