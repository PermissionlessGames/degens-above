# Degens Above

[Neeraj Kashyap](mailto:zomglings@game7.io)

In *Degens Above*, players play as gods, watching a never ending series of mortal chariot races.

At the beginning of each race is the betting phase. Players can bet on the outcome of that race in 1000 G7 increments.

Bets are hidden during the betting phase.

They can be revealed after the betting phase.

Players can reveal any number of bets at a time.

Revealing a bet mints the revealing player a *miracle*.

A miracle can be burned during the current race to speed up or slow down a single chariot. This costs another 100 G7, which goes directly into the pot.

10% of the pot is saved to seed the pot for the next race. The remainder of the pot is split among the players who bet on the winning chariot, in proportion to their bet size.

One race is active at any time. The next race starts as soon as the previous race ends.

A race consists of 16 chariots.

Any number of players can bet on the outcome of a race.

## Examples of gameplay

### Example 1: No whales

#### *Race setup*

* Chariot Speeds:  
  * 2 chariots at speed 4  
  * 2 chariots at speed 3  
  * 8 chariots at speed 2  
  * 4 chariots at speed 1  
* Track Length: 71 chariot lengths

*Betting phase*

* Speed 4 chariots dominate betting. \~100,000 G7 each (100 miracles per chariot).  
* Speed 3 chariots attract level 1 Keynesian beauty contest judges. \~80,000 G7 each (80 miracles per chariot).  
* One bettor isolates on a speed 2 chariot**.** 10,000 G7 (10 miracles)—a deep play waiting for chaos.

*Race*  
Total runtime: \~1 minute.

Phase 1: The Speed 4 War (Miracle Dumping Begins)

* Speed 4 bettors instantly burn miracles, speeding up their own chariot while slowing the rival.  
* Speed 3 bettors counter, slowing Speed 4 chariots into sub-speed 3 territory.

#### Phase 2: The Midfield Battles

* Speed 4 chariots burned out, stuck at speed 2— very few miracles left to climb back, likely not enough to counter those held by speed 3 bettors.  
* Speed 3 bettors shift focus to fighting each other, speeding up their own and slowing the rival.  
* The speed 2 bettor waits, holds miracles, maintains position behind the pack.

#### Phase 3: The Late-Game Pivot

* Speed 3 bettors exhaust most of their miracles battling for marginal gains.  
* The speed 2 bettor moves—burning miracles in a final surge.  
  * Speed jumps from 2 → 3 → 5 → 8\.  
  * Holds 4 miracles to counter incoming slowdowns.  
* Other players realize too late—they have very few resources left to stop it.

#### Phase 4: Attack, Revenge & The Collapse

* Speed 3 bettors attempt to slow down the speed 2 chariot with their remaining miracles.  
* Speed 4 bettors, now wrecked, burn final miracles out of spite to speed up the speed 2 chariot, wrecking speed 3 chances. Better to boost a sleeper than let those fucking speed 3 bettors profit. Speed 3 get wrecked.  
* The original speed 2 chariot crosses the line first\!

### Example 2: One whale

*Race setup*

* Chariot Speeds:  
  * 3 chariots at speed 4  
  * 6 chariots at speed 3  
  * 5 chariots at speed 2  
  * 2 chariots at speed 1  
* Track Length: 53 chariot lengths

*Betting phase*

* Minnows collectively control 100,000 G7.  
* A single whale controls 500,000 G7.  
* Minnows attempt to deduce the whale’s bet. Expecting a speed 4 backer, they mostly back speed 4 chariots.  
* The whale backs a speed 3 chariot instead—non-obvious, deceptive play.

*Race*  
Total runtime: \~45 seconds

#### Phase 1: Whale's Bluff & Minnow Overreaction

* The whale burns a few miracles buffing a speed 4 chariot—baiting minnows into committing their debuffs.  
* Minnows take the bait, assuming the whale is backing speed 4\. They dump miracles to slow down all speed 4 chariots.  
* Minnows burn most of their debuff miracles on a bluff.

#### Phase 2: The Minnow Resource Drain

* Minnows start realizing something’s off, but by then, their miracles are mostly spent.  
* The actual whale-backed speed 3 chariot is untouched, sitting at base speed.

#### Phase 3: Whale Reveals True Play

* With minnows mostly out of miracles, the whale begins steadily burning miracles to buff his real speed 3 chariot.  
* The speed 4 chariots are crippled—too slow to recover, no miracles left to counter.  
* The whale-backed speed 3 chariot pulls ahead uncontested.

#### Phase 4: The Payoff

* Whale wins the race. Minnows lose most of their money.  
* A small number of minnows who randomly backed speed 3 win as free riders—best ROI, zero miracle spend.  
* The whale extracts maximum value from the betting pool with superior play.

## Game theory

* **Hidden information.** Bets are not public until a player wishes to convert a bet into a miracle. Every reveal during the race phase discloses valuable information to the player base, and must be weighed carefully against the benefit of the miracle.  
* **Schelling point**. Players will naturally gravitate towards bets on the fastest chariots in a race. With 16 chariots and starting speeds uniformly distributed over 0, 1, 2, and 3, we still expect 4 chariots per race with the highest starting speed. If there is only 1 such chariot, it becomes a natural focal point for betting.  
* *Degens Above* may be a [**Bayesian game**](https://en.wikipedia.org/wiki/Bayesian_game). If it is, we can derive Bayesian Nash equilibria for it.  
* **Free rider problem**. Whales, especially, will have to contend with free riders on their chariots. This creates interesting dynamics to the game in the absence of whales *and* in the presence of whales.  
* **Keynesian beauty contest.** This comes into play when trying to formulate a common prior over the chariots.

## Design

### Race RNG

The chariots in each race are generated randomly. The source of entropy is the blockhash of the block prior to the one in which the race was created.

These 256 bits of entropy are used to generate the chariots participating in the race.

### Chariots

Each chariot has:

1. A starting speed `0 <= s <= 3`.  
2. Chariot color (4 bits \- 16 colors).  
3. Rider color (4 bits \- 16 colors).  
4. Horse color (4 bits \- 16 colors).

In total, the 16 chariots consume 16 \* 14 \= 224 bits of entropy.

![][image1]  
*Figure 1\. A pink chariot with a blue charioteer, being pulled by yellow horses.*

### Race course

The remaining 32 bits of entropy determines the length of the race course. If the 32 bits of additional entropy form the integer `c`, the race course is the following number of chariot lengths:  
`32 + c%128`.

### Chariot speed

The unit of speed for chariots is lengths/block.

When a miracle is applied to a chariot, it alters its speed permanently either by adding 1 to it or by subtracting 1 from it.

The speed of a chariot may be 0, but may not go below 0\.

The speed of a chariot may be 10, but may not go over 10\.

### Miracles are transferable ERC1155 tokens

New token ID for each race.

A miracle minted for a bet on one chariot can be used on any other chariot in either direction.

### Miracles for one race cannot be used in other races

Getting miracles in a race requires skin in the game \- only players who bet on the race get to extract miracles out of it.

And miracles generated in the course of a race must be used during that race.

### Multi-accounting

Miracles do not care whether a player is multi-accounting or playing with a single account. They are linear in the amount a player makes.

The only reason for a player to multi-account is to hide the true size of their in-game capital.

This feels unavoidable short of forcing players to identify themselves. Multi-accounts are part of the hidden information.

### 1000 G7 bets

Stakes should be high.

### 100 G7 miracle cost

This will make players think twice about spamming miracles.

It also creates a dynamic where players would like others who bet on the same chariot to spend *their* miracles on it rather than spending their own.

They have to balance their desire for the chariot to win against their desire to disincentivize free riders.

### Warm start

Timer doesn’t start on betting phase until at least one bet has been made.

If the pot contains more than the minimum bet size (currently 1000 G7), it will be \+EV for a single player to play the game. They should make the minimum bet.

### Bet sizes are public

While a player’s bets are not public, the amount of money they bet in the betting phase *is* public and known to all players.

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAJgAAAF1CAIAAACbDbSeAAAUpklEQVR4Xu2dva7kuBGF90m0T2LA6QROHHTkaJ9hARvraGE47tjJRt7EgCNHmzq5s4CT3WT8AANH48ATOHBwaalLl12qotgkRVYV1Tw4uJhpSWQVP/FHanX3F27oFPqCvjDUpwbIk2iAPIkGyJNoB+QrfWEooulNdIOgdkAOJet6vXqQ87/pZinVB2khK0n5fEF0s5QqgyRZTWfHSbM9B0iaE9JZcdI8Tw9y0suwqWiSemnKgZz0kmwkvMxRz1EU5MvLCz2mZ9H0bqI7SakayBkSzufy61/g/3rRw3oWze0mupOUqoG8XC6bfD79aTZ+ZX39LKKJvYnuJ6VqIGk+N5DXP/6Gvn4Wkby8tKaPtiB5p6SHdSuSl9epQM4dcQ/kPALTIzsUSQqrb5BkIe4pcpDL1v5FU0LSuvVRB2RwpQPmy1d6cIfC6ZAEtYacOiBxJtMWJO+UWqnWEs4FJhH8ilZ2EiDP1CmDkwh+ZXlRQxIgjaRaRTQRM9npgNRa2h0XzmIvO3qMiHRAak0kB4VTiFxi0cNEJATy5Ydv6D69KTg7Ph1Inu3u6PpKXzAiEj9Ojazm6JEiUgO57NaPIt3RsfGGHiyi+iDn05NTdOy0nZQSLhONnGW32aqh+iDxKiCS7RQZXY2JhM3zejqQnXZKHPBedngferyIREGShCelnLMUnx298TmqMtLUBznP/DxPb7znsrNGzlnC0UbOUbzeUblKlgbZ1+ia2B3Bmz3FVR8kzzCS8GS7U+I4eSKRvGhB7aUAspe7PFnd0W1Byp+dCiBJzsshJoUjjMyOwaTkp8kKIHPPXJLzpHH+pghHyFPgxvsvh8iqAsjIcx57tj+6bj71mNAdHVvH0RIbqwJIHP2SAMswaJK21jNLe8Kx8eCD1r3jWhlk4skLxgdO4plHVDBZ8IyEp8nKIHluEeMDl2PNaBMVCztifOByrKCOgiw+eR0bXe0seXBUPOyI8YHLsYI6CpKGznKLmx6+1Sv5v4g28bCA48bHTrKja02QWRNkMHMLnRLHwwOOW/EGZE2QPLGHVsw8KBxJwXnp2KlJK2gmZZBOL/OgNpGwUFOMS1gKkZI+SN3raKJNJCzUFGulow/SqV5+YeEwysZVMC6H1tFMh0AeufbAxoUs5ShpEwMLMt24HLHl2yGQ+C5rrVN4UgK5CYBFmGVc1FKaiA6B3ITL8km31ryCtQmARZhllZuuJkA6peHIq9Yc4b0pTUQWQcqvd3DtPLYC405JK2ujcpD4G5KOTJBg3dF1UzWLrcy+QJkBphwkXunwNHKtMq943etlgRUbZSORTjnITaAsjQJvChQUniB5VMXGYwytsoGMgpR8YADXy6M6Yl+swOhqFORSpogKns1Jt2SnfHaQmxpZSMd9L7yxDIFUWbj66qp3R7BYOoUgq19BO42Fa6NlDrYvv/U0WQiy4FnWFG/KbKwW52LQ9ypayi7I1qcwrotHUtH3WlrKLsjWN+pwXTySiva1ND01nxSk2Ljq0CKuaUa2QMosXCUpgu91NdMzgsRVLLWwMKr7XlczFYJE7XCLj4VeZnmQPIZGbpqRKwbZb4/E774tVbAYGhmqazdN2gJ53f68RIu0cfk8gHa+V9pGhSBRa2w0d6kj97pafwAWl3wkzgK3XrtWBkl02fleuohJCbTiY8Ilx79GprpbP/zRFiTX3A/iXYHsTys+JlK4MEtfLw2rhgpBkjmyWHwoJjvUvRtCVjqT0jRZNylQIUh6TY1UizFoGZyripQv2SnxUo6GdVj1QXrN+1SBSss9JiOdkoZ1WIUg6dXYvvBuZaIlHhatoB7LuX+TS+E9VR9dC0E6ckG2L74b6c0PtS2vgngAHEm60+FhVX+67CjIh1dFOHq67daz48Nv9YRBtJpklmXYuGhAh1UOMlG50fvuMgOuPv54PZwpZ2Dz2qQKMy4aTQ2ZAykmHFgtXW663tTuLAzqeUHGh/SHajpgFEgUpKnMXWantEaO6KlBuh2WMDzSXZEMJvLsIN1teQVTWmJ4fjmWuL+MREHGT3P7er39xRmRHRQ1QGYLZ0S36WmAzBbOiG7T0wCZLZwR3aanATJbOCO6TU8DZLZwRnSbngbIbOGM6DY9DZDZwhnRbXoaILOFM6Lb9DRAZgtnRLfpaYDMFs6IbtPTAJkn8o403aynEpBwyzFROO0TgPR3zEF0s55KQGYJpz1AttMAmSfyXAHdrKcBMk84nelpQT58dtK+cDrT84Aka7wBsp0GyDzhdKbnAUnWeKYyL5PZdAbIPJlNpy3IwJP5nUs0nZw7LwNknsym0xakM5x5mcymM0DmyWw6A2SezKYzQObJbDrSIE19XqJAJB26WU/NQfKPIdI9upLZXJqDPNk9AbO5NAfpDCdfILO5KIDs+l1JkgvdrCcJkGeaJs0mIgHyTDfqzCYiAdIZzj9Lls9IHZBLE/z3H3Qn8xogA9OkqVZI1AC56Mq+9ZPuYV6Wr4nlQDp2RtPN5jVAriKtYKohUjRAriKtMPV2D32AXMRXCqC+WNLob6I7aUgOJM0eie5qWLxTguh+4jIBsq9O6UI46R7iUgDp2G9gLS92JRK8hfh1QDr2Qy19fZqABD89D0g/FuHvDd82hX5bJIqPqxaCFwJ5T3gfZC8zJQkbRHcSlyhI8jNYrX9ksIX2LqLofuKSAOmTxxSDndL+TEkC9qL7iUsCJKQa/LVB/sMa9GBjItF60f3E1RxkcJkT6ZSWZ8rgMgdEdxVXc5D3VBlCcEczJYkTi+4qLiGQnB/2tk30G4XqdflDgiSih4hrgEwVCZKI7i2utiDveTJ43bHE4Rm8xSgBMrhe7QskDc9ewA1B3pNk2LjJksfUBSVfrD4jyJTuCN62jH7TeNHATEbbHCQHtudty+g3jdcmqp1o1S9/W4F8eB+A2+boikOaUDrknpR6tK1A+gw5sIhRy9yO1RaZHXGo1u5jtAXJUcVNTnP18QoHwyd7vHU6JciCcdUbN436eIWDiYe67KCqJiAhMX4Kp3jbOJqtQyNhoZLxgx4vq4YgeeYpxk2zFKKnTRgsTsceIaPHy8ocSCOnOV7mRIYWFKlaqKD6ICPPAyQat47WNIlj4BEGQ72qfjdCfZD+s3M87UTj1lnKEVfkqsNaqF71QUJK8wjJ0070tnEULkJw7Ty8SKi0IEG1AhmZVx5a/aYJrp2Hh433XHbWUyuQPOcsb9tHtIE29bLAiI0szdwAybWplwVGTG7U0bIa6ZW+4MyC1DrTcaWJswM+hBYnqMogj9ycI8YNJLayx5XykILGh8ivy7yqgLx3dbj2SDyX48YNNImc7OlXHdg6oytTFZB3QTJVQMq/E4Kry0oBH0gLlZJdkMJv+JV1R/DmQCU1ATkz4NkWGDfQ1LiNcEW5JyI+Vv6qF2QapOT0s6mIRRI3PnY5XEOmQTqpNjoyrjo2ndPSRTRALsJV5I6rjo0cAusyriYgC9pizzIn+6YKFkOKcQlLIeKyDtK1X0okvocct8wJF1FNkP4t5SPvYXG3bqNN4az2RKs/lNsBSNdy4KIls6rTTYuSVU2QfozqFGTxuArGRU1Vg0xRE5BLGizPI250u+7gVQcxLmoSH137AOlYM9G6i4QLPNgdHZsmp0pBJqomSPyV5TzPg66+mqjbHcG4wKneyJGibkA61ky0+kzR0lh1BSZlHj/b0lUTJM6BJ3ncuPyliv/8jUaQo01RrK4yk7l8KVlKPYF0nGXpr8DQclhFxaYlS6lzkPOLRQqUc9z/Xv6SksWmyc5ABlaG//sXjeORaAmsloOm5YuoM5CON9On7E6Jjv5yLaGqUfmLaPVt1B9I+p7RD9/QOKJqcdVBjMtfqhBRfyAdb6lPGZ0ycGxtN7oPFddZQCYvX/GBx+/m7BnXMol0yi5B0md54PUECYyrYPrWW/6KLFddgnS8pT4lgcSHtOuOYFxX7kReoF5BOt5Sj2704P2n9hHS6hrrJCDXGqMK7N/StLrG6hhk7uiKd249rjoeXuNpsmOQbnvWL6/sN5bYMsebXu/+/a80pqqqCbL121jcqKFule5fhNA9WVEtTCttqZogN0GzrFqYXofs90jY4cvb39bj6hwVfz9ranxnoBVILdGY3rTZhzX9EfP7+Htq+nHdAbLEe30urj5A+odaFRUZu/BuHMyey4DticZUVecBGX9ABu+ZPhhWUeT0qqhqIN3hofUSEt1pXzQaJHLtkVVsgebyZeBh1QTpbk2WngZu30u0Px1U3dEiPUFJVQaZJTGQ7thoYZMc0bOA9CLDLNG81T6zoJ4OJOjlTXRDVDC5Nr2KKNaTgiyQD3WKLqy0NECmCnEcILc6L8hX+kJ7DZCpQhwfglSQJkh8YT5AHpQVkDZbB8t4qANkqnC0dJsBaYJEEI22DtYAuSsE0WjrYFUGWXthewdZu+THQhArtU5LVQaZqGQqo0emynioA2SqjIc6QKbKeKgDZKqMh2oZZPJEL6JoqPqyDNKWjIeqBpI/R0P3MCbjoaqB5E+20T2MCUdLtxmQGkjcLpPV5yewcLR0mwFZAUk32xOONvdhHwENkKnC0ZobP16VQHa30nFbkAZndB2Q/OFSuoc9GQ9YByRpFIPtwvU4YNUbGANkqowHbAKkubVDSCRmullbA2SqSMx0s7ZMgDR4WcZFYqabtWUCJN1sUsZjHiBTZTzmATJDPmCDk7oOSHxDwGCjRGT2k7DNQfqPlF5vurzJg2whXwsIqgb5eF4EeeBKG9VbDeTLDVVrQufTtdKAdAjkC7v3Dbq8ezf75bvvZrsff/SGV65ffw2G3WbT47uSz2I25AVp8vQhZXo80hGohSBJBCRieb+yV3rx3HSkMctwZoO84k+nvnvHIxsu89xfEc3slXwGSDyQ8jiGa9k3clbXzAAJpY9eKGDfOymDfSWB9MMpr3K4naHNE3EmgRwUtVwT5KCo6Q8fElkmgZyHbFrBsJRhXrs8etzrAcjRHS0YKMTv7cVAwrnAy1Xwe/bKU/nz54cDbAzk6I52fBTk9dtveaHD8oZ3IyIz5S5IQ+Pq8OyPH+OdchfkGFetGYjsLXliIMdVhynP01xkdA2DhPvjvKzT+T17xbQjo2sYJEytvKBhXWeDXA9gBQ3reoA8iQfIk/jZQfLnoDo1PLtFad10KpDwiB5+mg1eh3S88Ka+DE8OUFo39Q0y/nQhF3/6sq9rZXjkjtK6qVeQhMcvf3X5w19e5r/4xT199fvrzz99JCXwKmx6CTWkzkDi1p95cHJA9Pt/uj3PR+H95//O++NXLPfRM/RI8tin10yO00o0hjr/G//XJs7uQfr2xeJgykz6qJdBlh0vdvhyJj5yHnGQKA9J0b2C5BR561c3mTInA+3g3eV15KYtRRAS4w76u9+aeFKiP5C+BUG8lcXscfIg5b1GEpJFkFA7iLdsml/ZK4fs4+HRSnqNISRzIH2TzV2BN6iW8cTJYxbzGkBItkD61c2Rq8NGxlMmj1zGa+0hGQLpm4k3ohH7fqn12cKVS0jmQJoaUbkhSPnGAa9Vh2QFJNRonCIYQhVuH/Bab0gmQEJ1XVD8XnXhs1YakiGQvMnMGgKexL/OZOUSkj5IqIs3lnFD2GKtBF5rDEkZJNwF5s1k3x6kTEOB1+pCUgYJFfFm6sIQvExDgdfqQtIH2csah9vfIhC7rDQKEmrhDdSRIQWBtgKvdYWkDLLf7gj2IGU6pV2QvGm6s2fJE6xuiyD7Xa8SPztIqIK3S48WaC7wANnWkIvAXR5zIP1DqrxRejTk0rTFwGstIemAhPINvntcZn8bnWda1wNkc7duMfAA2dytWww8QDZ36xYDD5DNDZ8L45nWtVGQ01lWrd+/3UDnmda1RZDw5CNvkU49QNIW6dTPO7Se5l4ruHWLgQfI5m7dYmCLIE82tLZuMbBFkKB2Hz+WNKx0BD6qbhfkOS4lWzeX91pRSDogYVw9zejaurm8zYGErxmBv7xdunPr5vI2B9KdaHSVuRUAtggS/5Ipb52OPIksc8Arl5DUQLpbWHBDhLdOL5bsjs4ySFC/o6tMQ3mv1YWkCdIhlryN7Fvs8tG7A5BThywnWYrOMsh+lzxiTYS9VhqSMkiHHo3saKaEQXX+y9NpatMgXYczpXD7eK/1hmQCZGSA/TNrRHULNw72WnVIJkCCodKJsTRliPDnnz7y+AW8cgnJIkjL722ptIz3WntIFOTr7a9WuPa/i07mA617zgAJ0gLpUL+09mFmxTbxXmMIyRxIZ+8uAdwQVmwQ7zWMkCyCdJZY+q/u4EHKe40kJKMg3Zal1jALtQvfh4sY4qG0brILEgyRgCRXs75Sgc8hp7u/L6fH9m06iXRNxS9/fOi+QTr2e0qNcOIqJkvpe3cPErxp5qo4ScmmhlPsk4AEb5r8TQVQ/UUFFq/OlAV/Uuk9e6WByUiLNeP56vZLgpzcV6GfKfQy2wu9X0VByhq/bVIm3VtuuT4tSPD19rvKGz6P1Bc/75ODDPrl9sPZ19vvYtsfNhP9jCBP6QHyJB4gT+IB8iTu/seyh8ED5Ek8QJ7EA+RJPECexAPkSTxAnsQD5Hk8QJ7EJwf5yl45pcctupO4BGSnb72e22sHC2mA7MkD5ElcAnI5gBU0rOsB8iSeoVwuF0rrpgGyJ89QXl5eKK2bBshuHLn2cHsg5/47QFrzTOR6vVJUbwqDdLdOeZrHQU/gyO1yUAzk6JR2vOLY1y7IeVKdxtWkGcfHVRcB6UanNOOH3dGlgLya+SqEp/XD7ujiIN3olAac0h3dQ5BusHzg9+yVmobG37sJgJUKcqx65O0/mE2RhPQYpHtjuZTIKhtu5HubpykJ5DzTDpaSzqXoEkGCfOlLBazu4Sr2Lbz3LseeMkCCEM0xcVYz+VYL2ugJygbptixB41qz2ARhbkf0KgEJwhMn19xZ4YsYeOhhf/iw+ONH9/nz6i4Eoc5hz8HzpJDhyynmZtn7AhJacqbKQXrFiQ5FNPe/lGvEFFUAWayXfF2Nicb3Jppqe2mCHKqoAfIkGiBPogHyJBogT6IB8iT6P493QmaHQESjAAAAAElFTkSuQmCC>

## Comparable games

* [Zed Run](https://zed.run) \- a web3 horse racing auto battler, very successful in 2022, still has a small but loyal following  
* [Enzo Racing](https://x.com/EnzoRacingGame) \- a fully onchain game, project seems dead  
* [Roach racing](https://x.com/RoachRacingClub) \- looks like trading gamified as a race?