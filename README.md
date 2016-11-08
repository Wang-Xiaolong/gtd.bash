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
## Concept
As in the above flow chart, everything are organized in the 8 boxes.
Each thing is represented as an decimal 'id', and has a few attributes.
A few commands can be used to operate your stuff library.
### The Boxes
```
Box Name   Abbr.
inbox      i
todo       t
wait       w
project    p
log        l
reference  r
someday    s
trash      h
```

### The Commands
```
Command    Abbr.
init
add        a
remove     rm
to         t
view       v
edit       e
list       l
set        s
unset      u
install
shell
```

### The Attributes
```
Attribute    Abbr.
ctime        c
utime        u
context      x
due          d
owner        w
priority     p
sensitivity  s
category     g
tag          t
parent       r
type         y
```
