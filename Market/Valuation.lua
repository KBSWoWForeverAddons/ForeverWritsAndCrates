-- Forever Writs and Crates: Market valuation and greedy Favor/Receipt calculator.
local _, FWC = ...

local V = {}
FWC.Valuation = V

V.MAX_PLAN_STEPS = 2000

function V.Quote(entry, count)
	local q = { count = count, exact = false, listed = false }
	if type(entry) ~= "table" then
		q.unknown = true
		return q
	end
	q.at = entry.at
	q.source = entry.source
	q.seenDays = entry.seenDays

	if type(entry.exact) == "table" then
		q.exact = true
		local levels = {}
		for _, lvl in ipairs(entry.exact) do
			if type(lvl.unit) == "number" and type(lvl.qty) == "number" and lvl.qty > 0 then
				levels[#levels + 1] = lvl
			end
		end
		table.sort(levels, function(a, b)
			if a.unit ~= b.unit then return a.unit < b.unit end
			return a.qty < b.qty
		end)
		local got, cost = 0, 0
		for _, lvl in ipairs(levels) do
			if got >= count then break end
			local take = lvl.whole and lvl.qty or math.min(count - got, lvl.qty)
			got = got + take
			cost = cost + take * lvl.unit
		end
		q.listed = got > 0
		if got >= count then
			q.cost = cost
			q.unit = got > 0 and (cost / got) or 0
			q.surplus = got - count
		else
			q.short = count - got
			if levels[1] then q.unit = levels[1].unit end
		end
		return q
	end

	local qty = tonumber(entry.qty)
	if qty == nil and type(entry.min) == "number" then
		q.listed, q.stockUnknown = true, true
		q.cost, q.unit, q.surplus = entry.min * count, entry.min, 0
		return q
	end
	qty = qty or 0
	q.listed = qty > 0
	if type(entry.min) == "number" and qty >= count then
		q.cost = entry.min * count
		q.unit = entry.min
		q.surplus = 0
	else
		q.short = count - qty
		if type(entry.min) == "number" then q.unit = entry.min end
	end
	return q
end

function V.BetterQuote(a, b)
	if not b then return true end
	if a.cost and b.cost then return a.cost < b.cost end
	if a.cost then return true end
	if b.cost then return false end
	if a.unknown ~= b.unknown then return not a.unknown end
	return (a.short or math.huge) < (b.short or math.huge)
end

function V.BundleQuote(book, bundle)
	local best
	for _, id in ipairs(bundle.items or {}) do
		local q = V.Quote(book.items[id], bundle.count)
		q.item = id
		if V.BetterQuote(q, best) then best = q end
	end
	if not best then
		best = { count = bundle.count, unknown = true, exact = false, listed = false }
	end
	best.bundle = bundle
	return best
end

function V.EvaluateCrate(book, crate)
	local row = { kind = "crate", crate = crate, id = crate.id, bundles = {} }
	local best
	for i, bundle in ipairs(crate.bundles or {}) do
		local q = V.BundleQuote(book, bundle)
		q.index = i
		row.bundles[i] = q
		if V.BetterQuote(q, best) then best = q end
	end
	row.fill = best
	row.crateQuote = V.Quote(book.items[crate.id], 1)
	row.bagCount = FWC.BagCount(crate.id)
	row.quality = FWC.ItemQuality(crate.id, crate.quality)
	row.tier = crate.tier
	row.favor = FWC.CrateFavor(crate)
	if best and best.cost and row.favor then
		row.perFavor = best.cost / row.favor
		if row.crateQuote.cost then
			row.total = best.cost + row.crateQuote.cost
			row.totalPerFavor = row.total / row.favor
		end
	end
	row.score = row.totalPerFavor
	row.fillScore = row.perFavor
	row.estimate = (best ~= nil and best.cost ~= nil and not best.exact)
		or (row.crateQuote.cost ~= nil and not row.crateQuote.exact)
	return row
end

function V.EvaluateWrit(book, writ)
	local row = { kind = "writ", writ = writ, id = writ.id, quest = writ.quest, needs = {} }
	local cost, allKnown, allUnknown, anyListed, est, latestAt = 0, true, true, false, false, nil
	for i, need in ipairs(writ.needs or {}) do
		local q = V.Quote(book.items[need.item], need.count)
		q.item = need.item
		q.index = i
		row.needs[i] = q
		if q.cost then
			cost = cost + q.cost
			if not q.exact then est = true end
		else
			allKnown = false
		end
		if not q.unknown then allUnknown = false end
		if q.listed then anyListed = true end
		if q.at and (not latestAt or q.at > latestAt) then latestAt = q.at end
	end
	if #row.needs == 0 then allKnown = false end
	row.fill = { cost = allKnown and cost or nil, exact = allKnown and not est, unknown = allUnknown, listed = anyListed, at = latestAt }
	row.writQuote = V.Quote(book.items[writ.id], 1)
	row.quality = FWC.ItemQuality(writ.id, 3)
	row.rep = FWC.Writs.Rep(writ)
	if row.fill.cost and row.rep then
		row.fillPerHundred = row.fill.cost / row.rep * 100
		if row.writQuote.cost then
			row.total = row.fill.cost + row.writQuote.cost
			row.perHundred = row.total / row.rep * 100
		end
	end
	row.score = row.perHundred
	row.fillScore = row.fillPerHundred
	row.estimate = (row.fill.cost ~= nil and not row.fill.exact)
		or (row.writQuote.cost ~= nil and not row.writQuote.exact)
	return row
end

function V.CheapestFavorRate(book, crates)
	local best
	for _, c in ipairs(crates or {}) do
		local r = V.EvaluateCrate(book, c)
		if r.totalPerFavor and (not best or r.totalPerFavor < best.totalPerFavor) then best = r end
	end
	return best and best.totalPerFavor or nil, best
end

function V.CheapestEmptyCrate(book, crates)
	local bestQ, bestCrate
	for _, c in ipairs(crates or {}) do
		local q = V.Quote(book.items[c.id], 1)
		if V.BetterQuote(q, bestQ) then bestQ, bestCrate = q, c end
	end
	return bestQ, bestCrate
end

function V.EvaluateReceipt(book, crates)
	local row = {
		kind = "receipt",
		id = FWC.RECEIPT_ITEM,
		favor = FWC.RECEIPT_FAVOR,
		rep = FWC.RECEIPT_REP,
		quality = FWC.ItemQuality(FWC.RECEIPT_ITEM, 1),
	}
	row.favorRate, row.favorRow = V.CheapestFavorRate(book, crates)
	row.emptyQuote, row.emptyCrate = V.CheapestEmptyCrate(book, crates)
	if row.favorRate then row.favorCost = row.favorRate * FWC.RECEIPT_FAVOR end
	if row.favorCost and row.emptyQuote and row.emptyQuote.cost then
		row.total = row.favorCost + row.emptyQuote.cost
		row.perHundred = row.total / row.rep * 100
	end
	row.score = row.perHundred
	row.fill = { unknown = (row.emptyQuote == nil or row.emptyQuote.unknown == true) and row.favorRow == nil }
	row.estimate = (row.favorRow ~= nil and row.favorRow.estimate == true)
		or (row.emptyQuote ~= nil and row.emptyQuote.cost ~= nil and not row.emptyQuote.exact)
	return row
end

local function RowRank(row)
	if row.score then return 1 end
	if row.fillScore then return 2 end
	if row.fill and not row.fill.unknown then return 3 end
	return 4
end

function V.SortByCost(rows)
	table.sort(rows, function(a, b)
		local ra, rb = RowRank(a), RowRank(b)
		if ra ~= rb then return ra < rb end
		if ra == 1 and a.score ~= b.score then return a.score < b.score end
		if ra == 2 and a.fillScore ~= b.fillScore then return a.fillScore < b.fillScore end
		return a.id < b.id
	end)
	return rows
end

function V.EvaluateAllCrates(book)
	local rows = {}
	for _, c in ipairs(FWC.Crates()) do rows[#rows + 1] = V.EvaluateCrate(book, c) end
	return V.SortByCost(rows)
end

function V.EvaluateOwnedCrates(book)
	local rows = {}
	for _, c in ipairs(FWC.OwnedCrates()) do
		local row = V.EvaluateCrate(book, c)
		row.ownedMode = true
		row.score = row.perFavor
		row.estimate = (row.fill ~= nil and row.fill.cost ~= nil and not row.fill.exact)
		rows[#rows + 1] = row
	end
	return V.SortByCost(rows)
end

function V.EvaluateAllWrits(book)
	local rows = {}
	for _, w in ipairs(FWC.WritsList()) do rows[#rows + 1] = V.EvaluateWrit(book, w) end
	return V.SortByCost(rows)
end

--------------------------------------------------------------------------------
-- Greedy Favor Calculator (handles stock depletion across shared materials)
--------------------------------------------------------------------------------
function V.CrateOffers(crates)
	local offers = {}
	for _, c in ipairs(crates or FWC.Crates()) do
		local favor = FWC.CrateFavor(c)
		if favor then
			for _, b in ipairs(c.bundles or {}) do
				for _, itemID in ipairs(b.items or {}) do
					offers[#offers + 1] = {
						kind = "crate",
						entry = c,
						value = favor,
						bundle = b,
						item = itemID,
						items = { { id = c.id, count = 1 }, { id = itemID, count = b.count } },
					}
				end
			end
		end
	end
	return offers
end

function V.PlanFavor(book, targetFavor)
	local plan = { target = targetFavor, achieved = 0, cost = 0, picks = {}, estimate = false, complete = false, used = {} }
	if type(targetFavor) ~= "number" or targetFavor <= 0 then
		plan.complete = true
		return plan
	end
	local offers = V.CrateOffers()
	local used, byOffer = plan.used, {}

	local function Marginal(offer)
		local total, est = 0, false
		for _, part in ipairs(offer.items) do
			local entry = book.items[part.id]
			local have = used[part.id] or 0
			local after = V.Quote(entry, have + part.count)
			if not after.cost then return nil end
			local before = have > 0 and V.Quote(entry, have) or nil
			total = total + after.cost - (before and before.cost or 0)
			if not after.exact then est = true end
		end
		return total, est
	end

	for _ = 1, V.MAX_PLAN_STEPS do
		if plan.achieved >= targetFavor then break end
		local best, bestCost, bestRatio, bestEst
		for _, offer in ipairs(offers) do
			local cost, est = Marginal(offer)
			if cost then
				local ratio = cost / offer.value
				if not best or ratio < bestRatio or (ratio == bestRatio and cost < bestCost) then
					best, bestCost, bestRatio, bestEst = offer, cost, ratio, est
				end
			end
		end
		if not best then break end
		for _, part in ipairs(best.items) do
			used[part.id] = (used[part.id] or 0) + part.count
		end
		local pick = byOffer[best]
		if not pick then
			pick = { offer = best, n = 0, cost = 0, value = 0 }
			byOffer[best] = pick
			plan.picks[#plan.picks + 1] = pick
		end
		pick.n = pick.n + 1
		pick.cost = pick.cost + bestCost
		pick.value = pick.value + best.value
		plan.cost = plan.cost + bestCost
		plan.achieved = plan.achieved + best.value
		if bestEst then plan.estimate = true end
	end
	plan.complete = plan.achieved >= targetFavor
	return plan
end
