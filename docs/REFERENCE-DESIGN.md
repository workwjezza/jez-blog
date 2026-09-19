# Reference design specification

Inspected live on 2026-09-19: `https://jacob.energy/` and its linked article
`https://jacob.energy/final-1.html`. Inspection included HTML/CSS, computed styles,
Chrome screenshots at 1440, 768, 520, and 390px (900px viewport height), hover, and
keyboard focus. Reference content and images were not copied into this project.

## Measured reference

| Property | Observed value |
| --- | --- |
| Rendered background | White browser canvas; both html and body are transparent |
| Body / ordinary links | `#2e2b23` |
| Secondary text | `#524c3e` |
| Article title / emphasis | `#000` |
| Separator | `1px solid rgba(0,0,0,.125)`; `27px 0` margins |
| Font | Arial, 14px, weight 400, 27px line-height |
| Name | 14px, weight 600, 22.4px line-height |
| Section labels | 14px, weight 600, 27px line-height |
| Desktop content | x=305px, width=700px at a 1440px viewport; name y=54px |
| Tablet reference | At 768px, x=305px and width=336px due to the sidebar grid |
| Mobile homepage | At 390px, text x=20px, width=350px; name y=85px |
| Intro spacing | 12px paragraph gap; 36px bottom margin plus 40.5px section padding |
| Experiment alignment | 180px title column; 8px/12px cell padding; 18.9px line-height; italic descriptions |
| Experiment mobile | At <=520px, title and description stack; 10px cell gutters |
| Writing | 40px row line-height; links padded 5px vertically / 12px horizontally |
| Ordinary hover | Opacity .5 |
| Writing hover | White on black, opacity .9 |
| Keyboard focus | Native Chrome auto outline, `rgb(0,95,204)` |
| Article title | 24px, weight 600; computed normal line-height (28px box) |
| Article body | 700px desktop column, 14px/27px; 13.5px paragraph margins |
| Article heading CSS | h2 24px/1.25, margin 54px 0 27px; h3 20px, margin 27px 0 |
| Article media | Responsive images; no requirement for a hero image |

The source declares `--background-color: #cfcbc2` on body but consumes it on html.
It does not resolve there; the screenshot confirms white. This implementation uses
explicit white rather than reproducing the unused variable. The inspected article
had no ordinary paragraph hyperlink to hover; its link-hover rule was verified from
CSS (black text and a translucent white background), not a rendered article link.

## Deliberate adaptations for this site

- Name, socials, Experiments, separator, Writing only. No sidebar, animations,
  navigation spacer, weather/footer, biography, copied imagery, or extra sections.
- Keep the reference's x=305px / 700px reading column on wide screens (>=1100px).
  Below that, center a fluid column, capped at 700px, with at least 20px gutters.
  This avoids keeping a sidebar-sized blank column at tablet widths and zoom.
- Desktop top padding stays 54px; mobile starts at 40.5px rather than reserving the
  reference's empty 75px navigation row. The intro has a 40.5px gap before sections,
  rather than reproducing the stacked 76.5px margin/padding. No minimum heights.
- Four plain social links sit on one wrapping line. Their order and exact labels
  come from site configuration, not the reference's identity.
- Experiments retain title/description column alignment and mobile stacking but
  omit table boxes and divider lines. They are a semantic list, not cards or a grid
  of decorative containers. Absent descriptions emit no placeholder paragraph.
- A 2px blue focus-visible outline is explicit rather than browser-dependent.
  No transitions or animations. Writing-link hover retains the reference style.
- The reading page has one inline back link, a title, an optional unobtrusive date,
  and Markdown. No author byline, automatic subtitle, copy button, or hero image.
- Article text links get a subtle dark hover tint so feedback remains visible on
  white; code uses plain monospace. Long URLs, code, and titles wrap rather than
  hiding overflow. Media stays within the reading column.

This is a measured, reduced-scope adaptation—not a pixel-identical reproduction.