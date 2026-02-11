/**
 * JavBus 本地 Spider - 代理强化版
 * 结合 Worker 的图片代理能力，确保海报 100% 显示
 */

// --- 配置区 ---
var workerUrl = "https://hak.486253sg.eu.org"; // 填入你刚才测试通过的 Worker 域名
var siteUrl = "https://kt.guykjy.useruno.com";

function init(ext) {
    console.log("JavBus Spider Initialized");
}

// 1. 首页与筛选配置
function home(filter) {
    var classes = [{"type_id": "anc", "type_name": "🏠 本地·代理增强版"}];
    var filters = {
        "anc": [{
            "key": "f",
            "name": "类型标签",
            "value": [
                {"n": "👣 丝足", "v": "28"},
                {"n": "⛓️ 折磨", "v": "62"},
                {"n": "🤮 呕吐", "v": "5g"},
                {"n": "🐙 触手", "v": "59"},
                {"n": "👶 处男", "v": "52"}
            ]
        }]
    };
    return JSON.stringify({ "class": classes, "filters": filters });
}

// 2. 一级分类/筛选 (核心：通过 Worker 代理图片)
function category(tid, pg, filter, extend) {
    var fValue = (extend && extend.f) ? extend.f : "28";
    var page = pg || 1;
    var url = siteUrl + "/api/movies?filterType=genre&filterValue=" + fValue + "&page=" + page + "&magnet=all";
    
    var response = http.get(url, { headers: { "User-Agent": "Mozilla/5.0" } });
    var json = JSON.parse(response);
    
    var videos = [];
    if (json && json.movies) {
        json.movies.forEach(function(it) {
            videos.push({
                "vod_id": it.id,
                "vod_name": "[" + it.id + "] " + it.title,
                // --- 核心修复：借用 Worker 的代理路径处理图片 ---
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

// 3. 详情页 (获取磁力)
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
        // 注意：这里也需要借用 Worker 的 /play 逻辑来跳转磁力
        "vod_play_url": "立即播放$" + workerUrl + "/play?id=" + it.id
    };
    
    return JSON.stringify({ "list": [vod] });
}

// 4. 搜索
function search(wd, quick) {
    var url = siteUrl + "/api/movies/search?keyword=" + encodeURIComponent(wd) + "&page=1&magnet=all";
    var response = http.get(url, { headers: { "User-Agent": "Mozilla/5.0" } });
    var json = JSON.parse(response);
    var videos = [];
    if (json && json.movies) {
        json.movies.forEach(function(it) {
            videos.push({
                "vod_id": it.id,
                "vod_name": it.title,
                "vod_pic": workerUrl + "/proxy-img/" + encodeURIComponent(it.img),
                "vod_remarks": it.date
            });
        });
    }
    return JSON.stringify({ "list": videos });
}

export default { init, home, category, detail, search };