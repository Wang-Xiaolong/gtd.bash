# gtd.sh -- a bash script for Getting Things Done
This is a bash script for myself to implement Getting Things Done(GTD).

You are here so you probabaly had known what's GTD,
David Allen's system of execution, for everybody,
especially the people nearly lost in the mountains of working pressure.

Here is the flow chart of GTD.

```
                          stuff ... stuff ...
Collect                             ↓
                                 ┌──┴──┐              ┌─────┐
                                 │Inbox│            ┌→│Trash│
                                 └──┬──┘            │ └─────┘
          ┌────────┐    yes         ↓       no      │ ┌─────────────┐
Organize  │Projects│←───────── Actionable? ─────────┼→│Someday-Maybe│
          └───┬────┘multi-step      ↓ yes           │ └─────────────┘
              ↕                What's Next?         │ ┌─────────┐
            Plan      <2min  Do↓ ↓Delegate↓Defer    └→│Reference│
                  ┌────────────┘ │        ├─────────┐ └─────────┘
                  │  ┌───────────┴┐  ┌────┴───┐ ┌───┴─────┐
                  │  │Waiting List│  │Calendar│ │Todo List│
                  │  └──────┬─────┘  └────┬───┘ └───┬─────┘
Do/Review         ↓         ↓             ↓         ↓
```
Here is the basic command - data flow chart of gtd.sh.
```
                          stuff ... stuff ...
Collect                          add↓
                                 ┌──┴──┐  remove      ┌─────┐
                                 │Inbox│ ┌───────────→│Trash│
                                 └──┬──┘ │            └─────┘
          ┌────────┐to-project      ↓    │to-someday  ┌─────────────┐
Organize  │Projects│←───────┬───────┼────┼───────────→│Someday-Maybe│
          └────────┘  to-log↓       ↓    │            └─────────────┘
                    ┌───────┘       │    │to-reference┌─────────┐
                    │            ┌──┴──┐ └───────────→│Reference│
                    │     to-wait↓     ↓to-todo       └─────────┘
                    │ ┌──────────┴─┐ ┌─┴───────┐
                    │ │Waiting List│ │Todo List│
                    │ └────────┬───┘ └───┬─────┘
Do                  ↓    to-log↓ ┌─────┐ ↓
                    └──────────┴→│ Log │←┘
Review                           └─────┘
```

