_Note: While this post was authored in June 2023, I got sidetracked by other
things, and am only getting around to publishing it and the accompanying code
now, in late 2024. Hopefully it's still relevant._

I'm no fan of rote memorization, but once in a while there are sets of facts
that come up that you just need to commit to memory. Flashcards can be very
useful when faced with such situations, and particularly when paired with the
concept of
[spaced repetition](https://en.wikipedia.org/wiki/Spaced_repetition)
for making efficient use of your mental muscles. The basic idea
is pretty intuitive: you should be spending most of your practice time
on the items (specific facts, terms to memorize, etc) you find most
challenging to recall. Other items that you've mastered still
need to be revisited, but can be reviewed less frequently.

Spaced repetition is an application of the broader concept of
[deliberate practice](https://en.wikipedia.org/wiki/Deliberate_practice),
a powerful principle for improving at any skill
centered on the idea of measuring performance and consciously identifying and
targeting weak points for improvement.

If you're at all familiar with these principles in the context of memorization,
you've undoubtedly heard of Anki, an open source app applying these
techniques to flashcard training. After completing a flashcard, the user
rates their degree of mastery over the contents of the card. This rating then
influences how soon the user will see the card again.

Anki is great, and I've had much success with it in the past! It provides
multiple graphical interfaces on different platforms, but in recent years I've
found myself wishing for a minimal command line interface for both training
and card creation.
That lead me to look into some of Anki's
internals and the details of the
[spaced repetition algorithm](https://www.super-memory.com/english/ol/sm2.htm)
it uses. It seemed to me that there might be a case for a lighter-weight
alternative -- or perhaps more importantly, it seemed like a
fun excuse to try writing some string-heavy [Hare](/hare) code. ;)

In this this post I'll outline the very simple, but seemingly effective,
card selection algorithm I came up with for `cards`, my own spaced
repetition flashcard application.

_Disclaimer: There are people who study these kinds of memorization methods
for a living - and I am not one of them! What follows isn't based on any kind
of evidence of its efficacy, and I also have to assume I'm not the
first person to implement something along these lines. While I didn't come
across this kind of approach in my research, I also didn't look very hard at
all! If you're aware of other work in the space of deriving (and especially
evaluating) small and elegant deliberate practice / spaced repetition
algorithms, please let me know! With that out of the way, this is what I came
up with..._

## Selection algorithm overview

In contrast to algorithms like SuperMemo, which deterministically schedules
the best card to present next given the current state of the deck, my crackpot
approach is fully probabilistic, with cards being drawn from the deck at
random, but with some cards given higher priority (and therefore assigned a
higher likelihood of selection) than others.

Like other algorithms, there are two pieces of information about each card
that influence its selection probability: how long it's been since the card
was last drawn, and how comfortable the user is with the contents of the card,
based on feedback provided by the user after seeing the question and
correct response. Both of these measures (hereafter referred to as "age"
and "difficulty") are then converted to indices in the range of zero to one.
These two values can then be plugged into a weighting function to determine
the probability of selecting any given card, and a random number can be
generated to determine which card will ultimately be selected and shown to the
user.

## Calculating the age index

As far as I can tell there are basically two options for expressing how
"recent" a given card is: how many cards have been drawn since the card was
last seen, and how much time has elapsed since the card was last seen.

Of course, in a world where cards are viewed constantly and at an even rate,
these two metrics would be essentially equivalent. In reality, people take
breaks -- either short ones, on the order of minutes, during a training session,
or long ones, on the order of days or weeks, between training sessions. They
may also spend more time on certain cards than others. There are certainly
benefits to each choice:

Age based on elapsed draws:

 - Based on simple counting logic, so no potential for complications arising
   from depending on a system clock (which might change between uses and break
   things)
 - Raw metadata (count of draws since last viewed) is easily understood by both
   humans and machines (vs other timestamping measures like seconds
   since Unix epoch, ISO 8601, etc)
 - Length of time spent on specific cards doesn't impact results

Age based on elapsed time:

 - Able to discriminate cards viewed just-before vs just-after breaks (e.g.
   when starting a new training session, you're more concerned about whether
   you've already seen a card this training session, but less worried about
   whether you saw a card at the beginning or end of your session yesterday
 - Age metadata (timestamp at last time viewed) only needs to be updated
   when the card is viewed, unlike card counts which need to be incremented for
   every card whenever any card is viewed (barring some more complicated use of
   a global view counter, etc)

In the end I elected to track age based on elapsed time, but I think
either approach could work just fine.

Each time a card is viewed, its metadata
is updated to reflect the current timestamp. Then, when calculating the card's
recency index in preparation for drawing subsequent cards, this timestamp
is considered relative to the largest and smallest timestamps of cards in the
deck as follows:

```
               timestamp of most recent card - timestamp of current card
Age index = ----------------------------------------------------------------
             timestamp of most recent card - timestamp of least recent card
```

The result is that the most recently practiced card scores 0.0,
while the least recently practiced card scores 1.0. The score of
other cards is the result of a linear interpolation in time between those two
extremes. My implementation uses the number of seconds since the Unix epoch for
timestamps, so cards that haven't yet been seen can just be assigned a default
timestamp of zero (making them look very stale and therefore highly likely to
be selected). Finally, in my implementation, if all cards in the deck happen to
have identical timestamps (which happens when using a flashcard deck for the
first time), the index is arbitrarily set to 0.0 for all cards.

## Calculating the difficulty index

To calculate the "difficulty" index we need to introduce a new
field of metadata, the "mastery" of a given card. In my initial implementation
this was the long-run
average of individual mastery values that have been provided for this card
each time after seeing it. This running average can be recomputed continuously
while storing only two numbers, the
total sum of mastery values assigned to the card to date, and the number of
times the card has been scored. Dividing the former by the latter yields the
long-run average.

This running average has the effect of infinite memory, where every mastery
entry, whether provided the first time you saw the card or just now,
is weighted equally. Thinking about it more though, it seemed perhaps
preferable to gradually discount old ratings in
order to better represent the card's "current" mastery estimate, rather than
the long-run historical average. This is easily accomplished by updating the
card's mastery value using a weighted average of the previous mastery value and the just-provided rating. The first time a card's mastery is rated it can be
directly assigned as the new mastery value.

This approach is mathematically-equivalent to assigning an
exponentially-decaying weighting to older ratings, with the weighted average
coefficient determining how quickly weights for older ratings die off. This
approach has the added benefit that updated card mastery values can be
calculated based on a _single_ state variable (the previous mastery value)
rather than two (the previous mastery sum and number of times the card's been
rated) as required for the uniform weighting method.

Once each card has been assigned a mastery value (or a default value, say
zero, is used when the card hasn't yet been rated), the card's difficulty index
can be computed. The formula for calculating the difficulty index is analogous
to calculating the age index:

```
                    max mastery in deck - mastery of current card
Difficulty index = -----------------------------------------------
                      max mastery in deck - min mastery in deck
```

Just as with age, this means the card with the highest mastery in the
deck (therefore needing the least practice) will have an difficulty index of 0.0,
while the card with the lowest mastery (needing the most practice) will have an
index of 1.0. If all cards in the deck have identical masteries, the difficulty
indices are all arbitrarily set to zero.

## Calculating probability weightings

Once difficulty and age indices have been computed for each card, we can
convert them into probability weights. Obviously, cards with both difficulty
and age indices near 1.0 should be more likely to be chosen, while having
both indices near 0.0 should correspond to a low probability. But how should
age vs difficulty be weighted? And how much more likely should a high-index
card be to be chosen than a low-index card?

After a bit of fiddling to find a weighting function with both nice theoretical
properties and satisfying practical performance, the solution I settled on was:

```
priority = mastery weight * difficulty index + (1-mastery weight) * age index
weight = (skew + 1) ^ priority  - 1
```

This function involves two parameters:

1. the mastery weight, another weighted averaging coefficient that determines
whether age or difficulty should have more impact on selection probability
(with a default of 0.5 representing an even emphasis between the two)

2. the skew, a positive parameter than defines how biased selection
probabilities should be towards high-priority cards and away from low-priority
ones. In my tests I found that a value of 20 felt about right for a default,
but this can be adjusted by the user.

This function has some nice theoretical properties:

- Cards with both difficulty and age indices of zero receive a weight of
  zero, and so will never be selected randomly (unless all cards have a weight
  of zero)
- Cards with difficulty and age indices of one have a finite upper bound on
  their weight (equal to skew), rather than going to infinity which
  causes numerical issues
- Cards with one low index and one high index won't have their overall index
  dominated by one or the other (which was the case in earlier version of the
  function where I was multiplying the two indices together - an index of zero
  in one dimension could cause a card to not be drawn, regardless of how high
  the other index might be
- As an exponential function, different low indices receive relatively similar
  small weights, while weights grow rapidly and differentiate as indices
  approach 1.0, making high-priority cards appear satisfyingly commonly while
  still allowing for the possibility of seeing lower-priority cards from time
  to time.
- A skew approaching zero causes asymptotic convergence to a uniform probability
  weighting across all cards, disregarding age or difficulty. As skew goes
  to infinity, the probability density concentrates into the highest-priority
  cards, converging asymptotically to a deterministic strategy of always
  drawing the highest-priority card in the deck

Once weights are calculated for each card, they can be converted to
probabilities by normalizing on the sum of all weights in the deck. A random
number between zero and one can then be generated and used to select a card
based on standard
[inverse cumulative distribution function techniques](https://en.wikipedia.org/wiki/Inverse_transform_sampling).

That's all for now - hopefully you found it helpful, or at least interesting!
If you want to dive deeper, feel free to poke around the `cards`
[source code](https://git.sr.ht/~gord/cards).

_Source code disclaimer: Hare has evolved a fair bit since I wrote this,
and there are likely aspects of the code that are no longer idiomatic (or,
let's be honest, never were). Also, feel free to let me know about all the
memory leaks you find... Manual memory management is a skill I lack but would
like to cultivate. More generally, constructive feedback is very welcome!_
