// Pure presentation logic, shared by the QML panel and Node regression tests.
var months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
var weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
function pageCount(n) { return n + (n === 1 ? " page" : " pages"); }
function isExpanded(state, key, fallback) { return state[key] === undefined ? fallback : state[key]; }
function dayGroups(groups) {
    var out = {};
    groups.forEach(function(g) { if (g.pages.length) out[g.day] = g; });
    return out;
}
// Calendar selection is navigation through the notebook, not an activity feed.
// Copy before sorting so Modified's timestamp-ordered list remains unchanged.
function pagesForDay(byDay, day, mode) {
    var pages = byDay[day] ? byDay[day].pages.slice() : [];
    if (mode === "modified") pages.sort(function(a,b) {
        return a.number-b.number || a.id.localeCompare(b.id);
    });
    return pages;
}
function monthNumber(day) { return Number(day.slice(0,4))*12 + Number(day.slice(5,7))-1; }
// Keep empty months between dated pages navigable without building an entire
// history of calendar grids. Both bounds also keep arrow navigation predictable.
function calendarRange(groups, fallback) {
    var numbers = groups.filter(function(g) { return g.pages.length > 0; }).map(function(g) { return monthNumber(g.day); });
    if (!numbers.length) numbers = [monthNumber(fallback || new Date().toISOString().slice(0,10))];
    var oldest = numbers[0], latest = numbers[0];
    numbers.forEach(function(n) { oldest = Math.min(oldest,n); latest = Math.max(latest,n); });
    return {oldest:oldest, latest:latest, count:latest-oldest+1};
}
function shiftMonth(number, delta, range) {
    var oldest = 12, latest = 9999*12+11;
    if (range) {
        oldest = Math.max(oldest,range.oldest);
        latest = Math.min(latest,range.latest);
    }
    return Math.max(oldest,Math.min(latest,number+delta));
}
function calendarMonth(number, byDay) {
    var year = Math.floor(number/12), month = number%12;
    // setUTCFullYear also handles years 1–99 without Date.UTC's 1900 offset.
    var first = new Date(0); first.setUTCFullYear(year,month,1); first.setUTCHours(12,0,0,0);
    var cells = [], pages = 0;
    for (var i=0; i<42; i++) {
        // Spillover dates are real navigation targets, not decorative padding.
        // UTC civil arithmetic avoids DST changing a visible day or its dot.
        var date = new Date(first); date.setUTCDate(i-first.getUTCDay()+1);
        var cellYear = date.getUTCFullYear(), valid = cellYear>=1 && cellYear<=9999;
        var inMonth = valid && cellYear===year && date.getUTCMonth()===month;
        var day = valid ? String(cellYear).padStart(4,"0")+"-"+
            String(date.getUTCMonth()+1).padStart(2,"0")+"-"+String(date.getUTCDate()).padStart(2,"0") : "";
        var count = day && byDay[day] ? byDay[day].pages.length : 0;
        if (inMonth) pages += count;
        cells.push({number:valid ? date.getUTCDate() : 0, day:day, count:count, inMonth:inMonth});
    }
    return {title:months[month]+" "+year, cells:cells, pages:pages};
}
function dayTitle(day) {
    return Number(day.slice(8))+" "+months[Number(day.slice(5,7))-1]+" "+Number(day.slice(0,4));
}
function rows(groups, state) {
    var ordered = groups.slice().sort(function(a,b) { return b.day.localeCompare(a.day); });
    var years = [], buckets = {}, monthKeys = [];
    ordered.forEach(function(g) {
        var y = g.day.slice(0,4), m = g.day.slice(0,7);
        if (years.indexOf(y) < 0) years.push(y);
        if (!buckets[m]) { buckets[m] = []; monthKeys.push(m); }
        buckets[m].push(g);
    });
    var out = [], manyYears = years.length > 1;
    years.forEach(function(y, yi) {
        var yearMonths = monthKeys.filter(function(m) { return m.slice(0,4) === y; });
        var yearPages = 0;
        yearMonths.forEach(function(m) { buckets[m].forEach(function(g) { yearPages += g.pages.length; }); });
        var ye = isExpanded(state, "y:"+y, yi === 0);
        if (manyYears) out.push({kind:"year", key:"y:"+y, title:y, detail:pageCount(yearPages), depth:0, expanded:ye});
        if (manyYears && !ye) return;
        yearMonths.forEach(function(m) {
            var count = 0;
            buckets[m].forEach(function(g) { count += g.pages.length; });
            var me = isExpanded(state, "m:"+m, monthKeys.length <= 3 || m === monthKeys[0]);
            out.push({kind:"month", key:"m:"+m, title:months[Number(m.slice(5,7))-1]+(manyYears ? "" : " "+y), detail:pageCount(count), depth:manyYears ? 1 : 0, expanded:me});
            if (!me) return;
            buckets[m].forEach(function(g) {
                var estimates = g.pages.filter(function(p) { return !!p.estimated; }).length;
                var de = isExpanded(state, "d:"+g.day, false);
                var depth = manyYears ? 2 : 1;
                out.push({kind:"day", key:"d:"+g.day, title:weekdays[new Date(g.day+"T12:00:00Z").getUTCDay()]+" "+Number(g.day.slice(8)), detail:pageCount(g.pages.length)+(estimates ? " · "+estimates+" estimated" : ""), depth:depth, expanded:de, pageId:g.pages[0].id});
                if (de) g.pages.forEach(function(p) {
                    out.push({kind:"page", key:"p:"+p.id, title:"Page "+p.number, detail:p.estimated ? "Estimated from last modified" : "", depth:depth+1, expanded:false, pageId:p.id});
                });
            });
        });
    });
    return out;
}
