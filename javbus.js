// javbus.js - TVBox 本地爬虫脚本
var appConfig = {
    ver: 1,
    title: "JavBus本地爬虫",
    site: "https://kt.guykjy.useruno.com"
};

// 1. 初始化配置 (对应南瓜 init)
function init(ext) {
    console.log("JavBus Init...");
}

// 2. 首页与分类筛选 (实现你想要的标签切换)
function home(filter) {
    var classes = [{"type_id": "anc", "type_name": "✨ 本地海报墙"}];
    var filters = {
        "anc": [{
            "key": "f",
            "name": "类型",
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

// 3. 一级列表与动态筛选 (核心：根据 f 自动跳转)
function category(tid, pg, filter, extend) {
    var fValue = extend.f || "28"; // 捕捉筛选标签
    var url = appConfig.site + "/api/movies?filterType=genre&filterValue=" + fValue + "&page=" + pg + "&magnet=all";
    
    var html = http.get(url, { headers: { "User-Agent": "Mozilla/5.0" } });
    var json = JSON.parse(html);
    var videos = [];
    
    json.movies.forEach(function(it) {
        videos.push({
            "vod_id": it.id,
            "vod_name": it.title,
            "vod_pic": it.img, // 本地爬虫无需代理，TVBox 会处理 Referer
            "vod_remarks": it.date
        });
    });
    
    return JSON.stringify({
        "page": pg,
        "pagecount": 100,
        "limit": 20,
        "total": 2000,
        "list": videos
    });
}

// 4. 二级详情 (点击海报后的逻辑)
function detail(id) {
    var url = appConfig.site + "/api/movies/" + id;
    var html = http.get(url, { headers: { "User-Agent": "Mozilla/5.0" } });
    var it = JSON.parse(html);
    
    var vod = {
        "vod_id": it.id,
        "vod_name": it.title,
        "vod_pic": it.img,
        "type_name": "JavBus",
        "vod_content": it.description || it.title,
        "vod_play_from": "磁力",
        "vod_play_url": "播放$" + it.magnet
    };
    return JSON.stringify({ "list": [vod] });
}

// 导出函数给 TVBox 调用
export default { init, home, category, detail };