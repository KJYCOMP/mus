/**
 * JavBus 本地 Spider - 三级架构版 (GitHub)
 */
var workerUrl = "https://hak.486253sg.eu.org"; // 你的 HAK 网关地址

function init(ext) { console.log("JavBus Init"); }

function home(filter) {
    var classes = [{"type_id": "anc", "type_name": "✨ 并发 12 页·海报墙"}];
    var filters = {"anc": [{"key": "f", "name": "分类", "value": [{"n": "👣 丝足", "v": "28"},{"n": "⛓️ 折磨", "v": "62"},{"n": "🤮 呕吐", "v": "5g"},{"n": "🐙 触手", "v": "59"}]}]};
    return JSON.stringify({ "class": classes, "filters": filters });
}

function category(tid, pg, filter, extend) {
    var fValue = (extend && extend.f) ? extend.f : "28";
    // 脚本向 HAK 请求，HAK 会去找 anc
    var url = workerUrl + "/list?filterValue=" + fValue + "&pg=" + pg;
    var res = http.get(url, { headers: { "User-Agent": "Mozilla/5.0" } });
    return res; 
}

function detail(id) {
    var url = workerUrl + "/detail?ids=" + id;
    return http.get(url, { headers: { "User-Agent": "Mozilla/5.0" } });
}

function search(wd) {
    var url = workerUrl + "/search?wd=" + encodeURIComponent(wd);
    return http.get(url, { headers: { "User-Agent": "Mozilla/5.0" } });
}

export default { init, home, category, detail, search };