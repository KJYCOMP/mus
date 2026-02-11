/**
 * JavBus 本地 Spider 脚本 (适配 TVBox)
 * 逻辑参考：南瓜.js / 飞猫.js
 */

var siteUrl = "https://kt.guykjy.useruno.com";

// 1. 初始化
function init(ext) {
    console.log("JavBus Spider Init...");
}

// 2. 首页配置 (实现筛选菜单显示)
function home(filter) {
    var classes = [{"type_id": "anc", "type_name": "🏠 本地·全能海报墙"}];
    var filters = {
        "anc": [{
            "key": "f",
            "name": "分类标签",
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

// 3. 一级分类/筛选 (实现点击标签自动切换海报墙)
// tid: 分类ID, pg: 页码, filter: 是否开启筛选, extend: 选中的筛选值
function category(tid, pg, filter, extend) {
    // 关键：捕捉 extend.f 的值，如果没有则默认 28
    var fValue = (extend && extend.f) ? extend.f : "28";
    
    // 构造请求 URL (支持分页)
    var url = siteUrl + "/api/movies?filterType=genre&filterValue=" + fValue + "&page=" + pg + "&magnet=all";
    
    // 发起网络请求
    var html = http.get(url, { headers: { "User-Agent": "Mozilla/5.0" } });
    var json = JSON.parse(html);
    
    var videos = [];
    if (json && json.movies) {
        json.movies.forEach(function(it) {
            videos.push({
                "vod_id": it.id,
                "vod_name": it.title,
                "vod_pic": it.img,
                "vod_remarks": it.date || ""
            });
        });
    }

    return JSON.stringify({
        "page": pg,
        "pagecount": 100, // 假设总页数
        "limit": 20,
        "total": 2000,
        "list": videos
    });
}

// 4. 二级详情 (点击海报获取磁力链接)
function detail(id) {
    var url = siteUrl + "/api/movies/" + id;
    var html = http.get(url, { headers: { "User-Agent": "Mozilla/5.0" } });
    var it = JSON.parse(html);
    
    var vod = {
        "vod_id": it.id,
        "vod_name": it.title,
        "vod_pic": it.img,
        "type_name": it.genre ? it.genre.map(g => g.name).join('/') : "JavBus",
        "vod_content": it.description || it.title,
        "vod_play_from": "磁力链接",
        "vod_play_url": "磁力播放$" + (it.magnet || "")
    };
    
    return JSON.stringify({ "list": [vod] });
}

// 5. 搜索功能
function search(wd, quick) {
    var url = siteUrl + "/api/movies/search?keyword=" + encodeURIComponent(wd) + "&page=1&magnet=all";
    var html = http.get(url, { headers: { "User-Agent": "Mozilla/5.0" } });
    var json = JSON.parse(html);
    var videos = [];
    if (json && json.movies) {
        json.movies.forEach(function(it) {
            videos.push({
                "vod_id": it.id,
                "vod_name": it.title,
                "vod_pic": it.img,
                "vod_remarks": it.date
            });
        });
    }
    return JSON.stringify({ "list": videos });
}

// 必须导出这些函数，TVBox 才能调用
export default { init, home, category, detail, search };