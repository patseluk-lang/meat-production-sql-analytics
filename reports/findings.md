# Key findings

All figures are produced by the queries in [`sql/analysis/`](../sql/analysis)
against the generated dataset (3 years: Sep 2023 – Aug 2026; 51 SKUs, ~300
B2B clients, ~71k order lines). Numbers are reproducible from a fixed seed.

## 1. The business at a glance
Revenue over three years is **₴596.2 M**, at an overall **71.9% gross margin
over materials** (COGS = bill-of-materials cost). Sales are dominated by the
wholesale channel: **distributors ₴458.5 M (77%)**, HoReCa ₴109.4 M (18%),
retail shops ₴28.4 M (5%). Losing one large distributor hurts far more than
losing many shops — concentration risk lives in the channel mix.

## 2. A narrow range carries the revenue (ABC)
**32 of 51 SKUs (A-class) generate 79.7% of revenue**; 12 are B-class and 7
are the C-class long tail. Combined with XYZ (demand stability), the premium
dry-cured lines (Салямі, Бекон) are **AX** — high value *and* stable — so they
should never be out of stock, while the erratic **Z** tail is where to cut
safety stock.

## 3. Premium is the profit engine (margin by category)
Gross margin ranges from **88.9% on Делікатеси** (aged dry-cured) down to
**54.3% on Варені ковбаси** (boiled sausages). Margin barely varies by channel
(~72% everywhere), so profitability is driven by **product mix, not by which
customer buys** — pushing premium SKUs raises blended margin more than chasing
a particular channel.

## 4. Spoilage tracks shelf life (write-offs)
Write-off rate is **7.3% for Паштети and 6.3% for Ковбаски/Гриль** (12–14 day
shelf life) versus **1.0% for Салямі and 0.8% for Делікатеси**. Average
production yield is a healthy **94.2%**. The lever is clear: tighten
forecasting and batch sizing on the short-life lines, where every extra
percent of write-off is pure loss.

## 5. Strong seasonality (production planning)
The seasonal index puts **December at 136 and January at 66** — December sells
roughly **twice** what January does — with a secondary summer lift (~108,
grill season). Production and cash planning should pre-build stock into
December and throttle back in January.

## 6. Customers are highly concentrated (Pareto + RFM)
**48 of 274 active clients (17.5%) generate 80% of revenue.** RFM segmentation
finds **69 "Champions" (74.4% of revenue)**, but also **7 high-value "cannot
lose" clients now dormant ~481 days** — a concrete win-back list. Cohort
retention declines from 100% to **~92% at 6 months and ~82% at 12 months**, so
about one client in five lapses within a year.

## 7. Cash is tied up in slow premium stock (inventory)
Fast movers turn over **20–28×/year (12–15 days of supply)** — pate and grill.
Premium deli turns just **~5×/year (~68 days of supply)**: high margin, but
slow, so it ties up working capital and needs tight lot control given its cost
per kg. Turnover was reconstructed from the movement ledger with a running
-balance window function — no stored stock level.

---

*Performance note:* two representative queries show a Seq Scan replaced by a
Bitmap Index Scan after adding an index — see
[`reports/explain/`](explain). The client-filter query drops from ~7.8 ms to
~0.4 ms (~18×).
