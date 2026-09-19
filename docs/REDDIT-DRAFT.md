# Reddit draft — not posted

Prepared 2026-09-20. The post below is for use **after** a public repository is
accessible and moderators approve it. Recheck the compatibility details then.
The current source repository is private and the license decision is pending.

r/Remarkable currently prohibits self-promotion:
[community rules](https://www.reddit.com/r/Remarkable/).
Do not post this as though it were an unrelated discovery.

## Ask moderators first

Hi mods — I've built a small, non-commercial reMarkable extension called
Notebook Dates. It adds a calendar/list inside notebooks so you can find pages
by creation date or last-modified date, without changing the normal table of
contents. It's running on my Paper Pro and Paper Pro Move.

I saw the rule against self-promotion, so I wanted to ask before posting.
Would a technical show-and-tell with screenshots, a GitHub link, and clear
firmware/installation limitations be welcome? I'm the author; this would not
be an ad, affiliate link, or paid service. Happy to follow whatever format
you prefer—or not post if it isn't appropriate.

## Suggested title

I built Notebook Dates: find reMarkable pages by date, in a calendar or list

## Post

I often remember *when* I wrote something more easily than which page it was on.
So I built **Notebook Dates**, a small extension that lets me browse notebook
pages by date, directly on the tablet.

It's separate from the normal table of contents: no automatically inserted
headings, no added text on your pages, and no changes to your handwriting.

Here's what it does:

- **Created / Modified:** switch between recorded creation dates and the
  notebook's own saved page-modification dates.
- **Calendar / list:** browse one month at a time, with dots on days that have
  pages, or expand a year/month/day list.
- **Tap to jump:** choose a date, then a page. Links still work if pages move.
- **Per-notebook opt-in:** enable creation tracking only where you want it.
  Modified view works without tracking.
- **Optional older-page estimates:** initialize undated pages from their last
  modification dates, clearly labelled as estimates—not recovered creation dates.
- **Configurable timezone** and optional **self-hosted date-history sync**
  between devices with the same notebook.

Local use is offline: no LLM, API key, account, or server required.
The optional sync hub handles date metadata, not handwriting or document text.
It doesn't replace normal reMarkable sync or move notebooks between devices.

It's running on my **Paper Pro and Paper Pro Move on 3.28.0.169**.
On the Pro there's a sidebar calendar icon; on Move it's under **⋮ → Dates**.

**Important caveat:** this is an unofficial, firmware-specific XOVI/QMLDiff
project. It isn't a one-click app-store install. The current deployment scripts
are tied to my qualified setups, and other firmware needs separate work.
Please read the compatibility and installation notes before trying anything;
don't bypass the guards. I'm sharing this as an early technical project, not
promising universal support.

**Code, screenshots and setup notes:** [Notebook Dates](https://github.com/guibor/notebook-date-index)

I'd be interested in how others would use it—daily work notes, meeting history,
journaling, or finding the last page you edited. Feedback on the date-navigation
idea and help making installation more portable would be very welcome.

## Attachments and publication checks

Use `images/dates-calendar.png` first and `images/dates-panel.png` second.
They are synthetic examples; label them as such if sharing the images.
Do not attach photos of private notebooks or private settings.

Before posting: replace the repository URL if a separate public source repo is
chosen, verify it while signed out, add license wording only once selected,
and obtain moderator approval. No claim of a public installer or complete
two-device offline acceptance is intended.
