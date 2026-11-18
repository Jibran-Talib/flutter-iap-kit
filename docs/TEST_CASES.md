# Test cases

`Auto` cases are covered by `flutter test`. `Manual` needs a real store.

## Purchase
| ID | Scenario | Expected | Type |
|---|---|---|---|
| P1 | Buy, backend verifies | premium, transaction finished once | Auto |
| P2 | Same token delivered twice | verified once | Auto |
| P3 | Backend rejects | failure message mentions Restore, transaction left open | Auto |
| P4 | Backend unreachable | "you will not be charged twice" message, left open | Auto |
| P5 | Rejection says expired | transaction finished | Auto |
| P6 | Nobody signed in | verification deferred, not finished | Auto |
| P7 | User closes the store sheet | `canceled`, no message | Auto |
| P8 | Buy while premium | blocked with a message | Auto |
| P9 | `itemAlreadyOwned` | restore runs | Auto |
| P10 | Real device purchase on release-signed build | premium after verify | Manual |

## Restore / renew / cancel
| ID | Scenario | Expected | Type |
|---|---|---|---|
| R1 | Restore with nothing owned | "No active purchases were found to restore." | Auto |
| R2 | Restore with 2 purchases | one backend call with both, both finished | Auto |
| R3 | Renewal while premium | verified quietly, no loader, no toast | Auto |
| R4 | Logout | previous user's status and plans cleared | Auto |
| R5 | Reinstall / second device, restore | premium again | Manual |
| R6 | Cancel in store | still premium until end date, then locked (needs server notifications) | Manual |
| R7 | Refund / revoke | locked on next refresh | Manual |
| R8 | Backend down during refresh | last known state kept | Manual |
| R9 | Sandbox/Play test renewals (minutes) | several renewals keep access | Manual |
