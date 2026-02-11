/**
 * JavBus 本地 Spider - 极致兼容版
 */

var workerUrl = "https://hak.486253sg.eu.org"; 
var siteUrl = "https://kt.guykjy.useruno.com";

function init(ext) {
    console.log("JavBus Spider Init");
}

function home(filter) {
    var classes = [{"type_id": "anc", "type_name": "🏠 本地·极致兼容版"}];
    var filters = {
        "anc": [{
            "key": "f",
            "name": "标签",
            "value": [
                {"n": "👣 丝足", "v": "28"},
                {"n": "⛓️ 折磨", "v": "62"},
                {"n": "🤮 呕吐", "v": "5g"},
                {"n": "🐙 触手", "v": "59"}
            ]
        }]
    };
    return JSON.stringify({ "class": classes, "filters": filters });
}

function category(tid, pg, filter, extend) {
    var fValue = (extend && extend.f) ? extend.f : "28";
    var page = pg || 1;
    var url = siteUrl + "/api/movies?filterType=genre&filterValue=" + fValue + "&page=" + page + "&magnet=all";
    
    // 使用更基础的 http 请求方式
    var response = http.get(url, { headers: { "User-Agent": "Mozilla/5.0" } });
    var json = JSON.parse(response);
    var videos = [];
    
    if (json && json.movies) {
        json.movies.forEach(function(it) {
            videos.push({
                "vod_id": it.id,
                "vod_name": "[" + it.id + "] " + it.title,
                // 这里确保 proxy-img 后面的编码绝对正确
                "vod_pic": workerUrl + "/proxy-img/" + encodeURIComponent(it.img),
                "vod_remarks": it.date || ""
            });
        });
    }

    return JSON.stringify({
        "page": page,
        "pagecount": 1, 
        "limit": videos.length,
        "total": 999,
        "list": videos
    });
}

function detail(id) {
    var url = siteUrl + "/api/movies/" + id;
    var response = http.get(url, { headers: { "User-Agent": "Mozilla/5.0" } });
    var it = JSON.parse(response);
    var vod = {
        "vod_id": it.id,
        "vod_name": it.title,
        "vod_pic": workerUrl + "/proxy-img/" + encodeURIComponent(it.img),
        "type_name": "JavBus",
        "vod_content": it.description || it.title,
        "vod_play_from": "高清磁力",
        "vod_play_url": "立即播放$" + workerUrl + "/play?id=" + it.id
    };
    return JSON.stringify({ "list": [vod] });
}

function search(wd, quick) {
    return JSON.stringify({ "list": [] });
}

// --- 关键：使用老式导出方式 ---
// @ts-ignore
globalThis.spider = { init: init, home: home, category: category, detail: detail, search: search };