// Pure presentation logic, shared by the QML panel and Node regression tests.
var months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
var weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
function pageCount(n) { return n + (n === 1 ? " page" : " pages"); }
function isExpanded(state, key, fallback) { return state[key] === undefined ? fallback : state[key]; }
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
