/**
 * JavBus 本地 Spider - 终极稳定版 (GitHub)
 */
var workerUrl = "https://hak.486253sg.eu.org"; 

function init(ext) { console.log("JavBus Init"); }

function home(filter) {
    var classes = [{"type_id": "anc", "type_name": "✨ 12页并发·稳定版"}];
    var filters = {"anc": [{"key": "f", "name": "分类", "value": [{"n": "👣 丝足", "v": "28"},{"n": "⛓️ 折磨", "v": "62"},{"n": "🤮 呕吐", "v": "5g"},{"n": "🐙 触手", "v": "59"}]}]};
    return JSON.stringify({ "class": classes, "filters": filters });
}

function category(tid, pg, filter, extend) {
    var fValue = (extend && extend.f) ? extend.f : "28";
    // 显式指向 /list 路径
    var url = workerUrl + "/list?filterValue=" + fValue + "&pg=" + pg;
    return http.get(url, { headers: { "User-Agent": "Mozilla/5.0" } });
}

function detail(id) {
    // 显式指向 /detail 路径
    var url = workerUrl + "/detail?ids=" + id;
    return http.get(url, { headers: { "User-Agent": "Mozilla/5.0" } });
}

function search(wd) {
    // 显式指向 /search 路径
    var url = workerUrl + "/search?wd=" + encodeURIComponent(wd);
    return http.get(url, { headers: { "User-Agent": "Mozilla/5.0" } });
}

export default { init, home, category, detail, search };