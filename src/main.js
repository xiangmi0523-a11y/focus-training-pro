import './style.css';

const modules = [
  { id:'schulte', icon:'▦', name:'舒尔特方格', subtitle:'视觉搜索 · 顺序注意', desc:'按从小到大的顺序依次点选数字。', levels:['4 × 4 方格','5 × 5 方格','6 × 6 方格','7 × 7 方格'] },
  { id:'color', icon:'◉', name:'字色干扰', subtitle:'抑制干扰 · 选择颜色', desc:'忽略文字写的是什么，只判断它显示的颜色。', levels:['4 个词语','6 个词语','8 个词语','10 个词语'] },
  { id:'number', icon:'⇅', name:'数值干扰', subtitle:'比较判断 · 数值排序', desc:'按数字从小到大依次选择。', levels:['4 个数字','6 个数字','8 个数字','10 个数字'] },
  { id:'memory', icon:'▣', name:'序列记忆', subtitle:'短时记忆 · 顺序复现', desc:'记住图标顺序，随后按原顺序复现。', levels:['3 个图标','4 个图标','5 个图标','6 个图标'] },
  { id:'direction', icon:'➤', name:'反向线索', subtitle:'规则切换 · 方向判断', desc:'根据本轮规则，选择箭头本身或其相反方向。', levels:['4 轮练习','6 轮练习','8 轮练习','10 轮练习'] },
  { id:'visual', icon:'字', name:'视觉完型', subtitle:'局部识别 · 视觉补全', desc:'观察缺失部件的汉字，选择最合理的完整字。', levels:['4 道题','6 道题','8 道题','10 道题'] }
];

const state = {
  page: 'home', moduleId: null, level: 1, game: null, countdown: null,
  timer: null, startedAt: 0, elapsed: 0, answerLocked: false
};
const defaultProgress = Object.fromEntries(modules.map(m => [m.id, { level: 1, streak: 0, sessions: 0, best: null }]));
let progress = load('focus-progress', defaultProgress);
let history = load('focus-history', []);
let app = document.querySelector('#app');

function load(key, fallback) {
  try { const value = localStorage.getItem(key); return value ? JSON.parse(value) : structuredClone(fallback); }
  catch { return structuredClone(fallback); }
}
function save() {
  try { localStorage.setItem('focus-progress', JSON.stringify(progress)); localStorage.setItem('focus-history', JSON.stringify(history)); }
  catch {}
}
function esc(s) { return String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }
function mod() { return modules.find(m => m.id === state.moduleId); }
function currentProgress(id=state.moduleId) { return progress[id]; }
function levelName(n) { return ['基础','进阶','高阶','极限挑战'][n-1]; }
function header(back=true) {
  return `<header class="topbar">${back ? `<button class="icon-btn" data-action="home" aria-label="返回">‹</button>` : `<span class="brand-mark">✦</span>`}<div class="brand"><strong>专注力训练 <em>PRO</em></strong><small>FOCUS · TRAINING</small></div><button class="icon-btn" data-action="records" aria-label="训练记录">◷</button></header>`;
}
function render() {
  clearTimer();
  app.innerHTML = `${header(state.page !== 'home')}<main class="page" id="page"></main><footer>循序渐进 · 专注当下</footer>`;
  const page = document.querySelector('#page');
  page.classList.add('enter');
  if (state.page === 'home') page.innerHTML = homeHTML();
  else if (state.page === 'detail') page.innerHTML = detailHTML();
  else if (state.page === 'records') page.innerHTML = recordsHTML();
  else if (state.page === 'game') { page.innerHTML = gameHTML(); if (state.countdown !== null) runCountdown(); }
  else if (state.page === 'result') page.innerHTML = resultHTML();
}
function homeHTML() {
  const done = history.length;
  const total = modules.reduce((n,m)=>n+progress[m.id].sessions,0);
  return `<section class="hero"><div class="eyebrow"><span class="spark">✦</span> YOUR DAILY TRAINING</div><h1>把注意力，<br><span>练成一种能力。</span></h1><p>每天一点点练习，记录自己的每次进步。</p><div class="hero-stats"><div><strong>${total}</strong><small>累计训练</small></div><i></i><div><strong>${modules.filter(m=>progress[m.id].level===4).length}<span>/6</span></strong><small>模块满级</small></div><i></i><div><strong>${done ? Math.round(history.reduce((s,h)=>s+h.score,0)/done) : '—'}${done?'%':''}</strong><small>平均完成率</small></div></div></section>
  <div class="section-heading"><div><small>TRAINING CENTER</small><h2>选择训练模块</h2></div><span class="count">06 MODULES</span></div>
  <section class="module-grid">${modules.map((m,i)=>{const p=progress[m.id];return `<button class="module-card" data-module="${m.id}"><div class="card-top"><span class="module-icon">${m.icon}</span><span class="card-number">0${i+1}</span></div><h3>${m.name}</h3><p>${m.subtitle}</p><div class="card-bottom"><span class="level-pill">LV.${p.level} · ${levelName(p.level)}</span><span class="arrow">↗</span></div><div class="mini-progress"><i style="width:${p.level===4?100:((p.level-1)*25+p.streak*12.5)}%"></i></div></button>`}).join('')}</section>
  <div class="note"><span>✧</span><p>训练建议：每天选择 1–3 个模块，按自己的节奏逐步挑战。训练结果仅反映本次练习表现。</p></div>`;
}
function detailHTML() {
  const m=mod(), p=currentProgress();
  return `<div class="detail-hero"><span class="module-icon large">${m.icon}</span><div class="eyebrow">MODULE ${String(modules.indexOf(m)+1).padStart(2,'0')}</div><h1>${m.name}</h1><p>${m.desc}</p></div>
  <section class="panel"><div class="panel-heading"><h2>选择难度</h2><span class="muted">连续两次达标即可晋级</span></div><div class="level-list">${m.levels.map((label,i)=>{const n=i+1, unlocked=n<=p.level;return `<button class="level-row ${n===p.level?'selected':''} ${!unlocked?'locked':''}" data-level="${n}" ${!unlocked?'disabled':''}><span class="level-number">${unlocked?'0'+n:'🔒'}</span><span class="level-copy"><strong>Lv.${n} · ${levelName(n)}</strong><small>${label}</small></span><span class="level-status">${n<p.level?'已通过':n===p.level?`达标 ${p.streak}/2`:'未解锁'}</span></button>`}).join('')}</div><button class="primary-btn full" data-action="start">开始训练 <span>→</span></button></section>
  <section class="panel compact"><div class="panel-heading"><h2>本模块记录</h2></div><div class="record-stats"><div><strong>${p.sessions}</strong><small>训练次数</small></div><div><strong>${p.best===null?'—':p.best+'%'}</strong><small>最佳成绩</small></div><div><strong>${p.streak}/2</strong><small>当前晋级进度</small></div></div></section>`;
}
function recordsHTML() {
  return `<div class="section-heading"><div><small>YOUR JOURNEY</small><h2>训练记录</h2></div><span class="count">${history.length} SESSIONS</span></div>
  <section class="panel">${history.length?`<div class="history-list">${history.slice(0,40).map(h=>`<div class="history-row"><span class="history-icon">${modules.find(m=>m.id===h.module)?.icon||'✦'}</span><div class="history-copy"><strong>${esc(h.name)} · Lv.${h.level}</strong><small>${esc(h.date)} · ${h.seconds} 秒</small></div><strong class="history-score">${h.score}%</strong></div>`).join('')}</div><button class="text-btn" data-action="clear-records">清空本机记录</button>`:`<div class="empty"><span>◷</span><h3>还没有训练记录</h3><p>完成一次训练后，记录会显示在这里。</p></div>`}</section><p class="privacy-note">记录仅保存在当前设备的本地存储中；清除浏览器/应用数据可能会删除记录。</p>`;
}
function gameHTML() {
  const m=mod(), g=state.game;
  return `<div class="game-heading"><div><div class="eyebrow">LV.${state.level} · ${levelName(state.level)}</div><h1>${m.name}</h1></div><div class="timer" id="timer">${g?.remaining ?? 0}<small>秒</small></div></div>
  <div class="game-instruction" id="instruction">${state.countdown!==null?'<span>准备开始</span>':esc(g?.instruction||m.desc)}</div>
  <div class="game-board" id="game-board">${g?boardHTML(g):''}</div>
  <div class="game-foot"><span id="game-progress">${g?`进度 ${g.done}/${g.total}`:'准备中'}</span><button class="text-btn" data-action="quit">退出训练</button></div>`;
}
function boardHTML(g) {
  if(g.type==='schulte') return `<div class="schulte" style="--n:${g.n}">${g.items.map(v=>`<button class="tile" data-value="${v}">${v}</button>`).join('')}</div>`;
  if(g.type==='color') return `<div class="choice-grid">${g.items.map((v,i)=>`<button class="choice color-word" data-index="${i}" style="color:${v.color}">${v.word}</button>`).join('')}</div><div class="helper">点击目标颜色：<b style="color:${g.target.color}">${g.target.name}</b></div>`;
  if(g.type==='number') return `<div class="choice-grid number-grid">${g.items.map((v,i)=>`<button class="choice" data-index="${i}">${v}</button>`).join('')}</div>`;
  if(g.type==='memory') return g.phase==='show'?`<div class="memory-sequence">${g.sequence.map(x=>`<span>${x}</span>`).join('')}</div><p class="helper">请记住顺序，图标即将隐藏</p>`:`<div class="choice-grid">${g.options.map((x,i)=>`<button class="choice emoji-choice" data-index="${i}">${x}</button>`).join('')}</div><p class="helper">按刚才的顺序选择图标</p>`;
  if(g.type==='direction') return `<div class="direction-rule">${g.reverse?'反向规则：选择箭头相反的方向':'同向规则：选择箭头指向的方向'}</div><div class="big-arrow">${g.arrow}</div><div class="direction-buttons">${['↑','→','↓','←'].map(x=>`<button class="choice" data-direction="${x}">${x}</button>`).join('')}</div>`;
  if(g.type==='visual') return `<div class="missing-char">${g.question}</div><div class="choice-grid">${g.options.map((x,i)=>`<button class="choice" data-index="${i}">${x}</button>`).join('')}</div>`;
  return '';
}
const colorSet=[{name:'红色',color:'#ed7770'},{name:'蓝色',color:'#76a9f5'},{name:'绿色',color:'#78c79b'},{name:'黄色',color:'#e8c766'}];
const emojiSet=['◆','●','▲','★','♥','✦','⬟','☾'];
const charQuestions=[
  {question:'日 + 月 = ?',options:['明','朋','旧','目'],answer:'明'},
  {question:'氵 + 青 = ?',options:['清','情','请','晴'],answer:'清'},
  {question:'女 + 子 = ?',options:['好','妈','她','如'],answer:'好'},
  {question:'口 + 十 = ?',options:['古','叶','田','吉'],answer:'古'},
  {question:'木 + 木 = ?',options:['林','森','本','休'],answer:'林'},
  {question:'人 + 木 = ?',options:['休','体','从','本'],answer:'休'},
  {question:'讠 + 青 = ?',options:['请','情','晴','清'],answer:'请'},
  {question:'日 + 寸 = ?',options:['时','对','早','明'],answer:'时'},
  {question:'扌 + 巴 = ?',options:['把','爸','吧','色'],answer:'把'},
  {question:'禾 + 火 = ?',options:['秋','种','和','香'],answer:'秋'}
];
function shuffle(a){return [...a].sort(()=>Math.random()-.5)}
function makeGame() {
  const id=state.moduleId, lv=state.level, g={module:id,done:0,correct:0,remaining:0,started:Date.now()};
  if(id==='schulte') {
    g.type=id;g.n=lv+3;g.total=g.n*g.n;g.items=shuffle(Array.from({length:g.total},(_,i)=>i+1));g.next=1;g.instruction='从 1 开始，按数字顺序依次点选。';
  } else if(id==='color') {
    g.type=id;g.total=[4,6,8,10][lv-1];g.target=shuffle(colorSet)[0];g.items=Array.from({length:g.total},()=>({word:shuffle(colorSet)[0].name,color:shuffle(colorSet)[0].color}));const idx=Math.floor(Math.random()*g.total);g.items[idx]={word:shuffle(colorSet)[0].name,color:g.target.color};g.items[idx].word=colorSet.find(c=>c.name===g.items[idx].word)?.name||g.items[idx].word;g.items[idx].isTarget=true;g.instruction='忽略文字含义，找出显示为目标颜色的文字。';
  } else if(id==='number') {
    g.type=id;g.total=[4,6,8,10][lv-1];g.items=shuffle(Array.from({length:g.total},()=>Math.floor(Math.random()*89)+1));g.next=[...g.items].sort((a,b)=>a-b)[0];g.sorted=[...g.items].sort((a,b)=>a-b);g.instruction='从最小的数字开始，按升序依次点选。';
  } else if(id==='memory') {
    g.type=id;g.total=[3,4,5,6][lv-1];g.sequence=Array.from({length:g.total},()=>emojiSet[Math.floor(Math.random()*emojiSet.length)]);g.options=shuffle([...new Set([...g.sequence,...shuffle(emojiSet).slice(0,4)])]);g.phase='show';g.index=0;g.instruction='记住图标顺序，随后依次点选。';
  } else if(id==='direction') {
    g.type=id;g.total=[4,6,8,10][lv-1];g.round=0;g.arrows=['↑','→','↓','←'];g.instruction='根据提示判断选择同向或反向箭头。';nextDirection(g);
  } else {
    g.type=id;g.questions=shuffle(charQuestions).slice(0,[4,6,8,10][lv-1]);g.total=g.questions.length;g.qi=0;setCharQuestion(g);g.instruction='观察部件提示，选择完整的汉字。';
  }
  return g;
}
function nextDirection(g){g.arrow=g.arrows[Math.floor(Math.random()*4)];g.reverse=Math.random()<.5;g.answer=g.reverse?g.arrows[(g.arrows.indexOf(g.arrow)+2)%4]:g.arrow;}
function setCharQuestion(g){const q=g.questions[g.qi%g.questions.length];g.question=q.question;g.answer=q.answer;g.options=shuffle(q.options);}
function runCountdown() {
  let n=3;const instruction=document.querySelector('#instruction');instruction.innerHTML=`<span class="countdown-number">${n}</span>`;
  state.timer=setInterval(()=>{n--;if(!document.querySelector('#instruction')){clearTimer();return;}if(n>0)instruction.innerHTML=`<span class="countdown-number">${n}</span>`;else{clearTimer();state.countdown=null;state.game=makeGame();state.startedAt=Date.now();state.game.remaining=0;renderGameOnly();if(state.game.type==='memory')startMemoryShow();else startClock();}},700);
}
function renderGameOnly(){const board=document.querySelector('#game-board');if(board)board.innerHTML=boardHTML(state.game);const ins=document.querySelector('#instruction');if(ins)ins.textContent=state.game.instruction;const p=document.querySelector('#game-progress');if(p)p.textContent=`进度 ${state.game.done}/${state.game.total}`;}
function startMemoryShow(){const g=state.game;renderGameOnly();state.timer=setTimeout(()=>{if(state.page!=='game')return;g.phase='pick';g.remaining=0;renderGameOnly();startClock();},Math.max(1500,2400+(g.total-3)*400));}
function startClock(){const g=state.game;g.started=Date.now();g.remaining=0;state.timer=setInterval(()=>{if(state.page!=='game'){clearTimer();return;}g.remaining=Math.floor((Date.now()-g.started)/1000);const t=document.querySelector('#timer');if(t)t.innerHTML=`${g.remaining}<small>秒</small>`;},250);}
function clearTimer(){if(state.timer){clearInterval(state.timer);clearTimeout(state.timer);state.timer=null;}}
function updateGame(){const g=state.game;const p=document.querySelector('#game-progress');if(p)p.textContent=`进度 ${g.done}/${g.total}`;if(g.done>=g.total){finishGame();return;}if(g.type==='direction'){nextDirection(g);renderGameOnly();}else if(g.type==='visual'){g.qi++;setCharQuestion(g);renderGameOnly();}else if(g.type==='color'){const idx=Math.floor(Math.random()*g.total);g.items=Array.from({length:g.total},()=>({word:shuffle(colorSet)[0].name,color:shuffle(colorSet)[0].color}));g.target=shuffle(colorSet)[0];g.items[idx]={word:shuffle(colorSet)[0].name,color:g.target.color,isTarget:true};renderGameOnly();}}
function handleGameClick(target) {
  const g=state.game;if(!g||state.countdown!==null)return;
  if(g.type==='schulte'){const v=Number(target.dataset.value);if(v===g.next){g.correct++;g.done++;g.next++;target.classList.add('used');if(g.done>=g.total)finishGame();else{const p=document.querySelector('#game-progress');if(p)p.textContent=`进度 ${g.done}/${g.total}`;}}}
  else if(g.type==='number'){const v=Number(g.items[Number(target.dataset.index)]);if(v===g.sorted[g.done]){g.correct++;g.done++;target.classList.add('used');if(g.done>=g.total)finishGame();else{const p=document.querySelector('#game-progress');if(p)p.textContent=`进度 ${g.done}/${g.total}`;}}}
  else if(g.type==='color'){const v=g.items[Number(target.dataset.index)];if(v?.isTarget){g.correct++;g.done++;if(g.done>=g.total)finishGame();else updateGame();}}
  else if(g.type==='memory'){const v=g.options[Number(target.dataset.index)];if(v===g.sequence[g.index]){g.correct++;g.index++;if(g.index>=g.sequence.length){g.done++;if(g.done>=g.total)finishGame();else{g.sequence=Array.from({length:g.total},()=>emojiSet[Math.floor(Math.random()*emojiSet.length)]);g.options=shuffle([...new Set([...g.sequence,...shuffle(emojiSet).slice(0,4)])]);g.index=0;g.phase='show';startMemoryShow();}}else{target.classList.add('used');}}}
  else if(g.type==='direction'){if(target.dataset.direction===g.answer){g.correct++;g.done++;updateGame();}}
  else if(g.type==='visual'){if(g.options[Number(target.dataset.index)]===g.answer){g.correct++;g.done++;updateGame();}}
}
function finishGame(){
  clearTimer();const g=state.game;const seconds=Math.max(1,Math.round((Date.now()-g.started)/1000));const score=Math.round(g.correct/Math.max(1,g.total)*100);
  const p=progress[g.module];p.sessions++;p.best=p.best===null?score:Math.max(p.best,score);
  const passed=score>=([75,80,85,90][state.level-1]);
  if(passed){p.streak++;if(p.streak>=2&&p.level<4){p.level++;p.streak=0;}}else p.streak=0;
  const record={module:g.module,name:mod().name,level:state.level,score,seconds,date:new Date().toLocaleString('zh-CN',{month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hour12:false}),passed};
  history.unshift(record);history=history.slice(0,100);save();state.lastResult={...record,passed,threshold:[75,80,85,90][state.level-1],levelNow:p.level,streak:p.streak};state.page='result';render();
}
function resultHTML(){
  const r=state.lastResult;
  return `<section class="result-hero"><div class="result-orbit"><span>${r.score}</span><small>POINTS</small></div><div class="eyebrow">SESSION COMPLETE</div><h1>${r.score>=r.threshold?'稳步前进。':'继续练习。'}</h1><p>${r.score>=r.threshold?'本次达到当前等级目标。':'本次未达到晋级标准，再练一次就更熟悉规则。'}</p></section>
  <section class="panel"><div class="result-row"><span>本次完成率</span><strong>${r.score}%</strong></div><div class="result-row"><span>训练时长</span><strong>${r.seconds} 秒</strong></div><div class="result-row"><span>本级达标要求</span><strong>${r.threshold}%</strong></div><div class="result-row"><span>连续达标</span><strong>${r.streak}/2</strong></div><div class="result-row"><span>当前等级</span><strong>Lv.${r.levelNow} · ${levelName(r.levelNow)}</strong></div><p class="result-note">${r.levelNow>r.level?'✦ 已解锁下一等级！':r.passed?'保持状态，再达标一次即可晋级。':'本次连续达标计数已重置。'}</p><button class="primary-btn full" data-action="retry">再练一次 <span>→</span></button><button class="secondary-btn full" data-action="detail">返回模块</button></section>`;
}
app.addEventListener('click',e=>{
 const b=e.target.closest('button');if(!b||b.disabled)return;
 b.classList.remove('jelly');void b.offsetWidth;b.classList.add('jelly');
 if(b.dataset.module){state.moduleId=b.dataset.module;state.page='detail';render();return;}
 if(b.dataset.level){state.level=Number(b.dataset.level);render();return;}
 if(b.dataset.value||b.dataset.index!==undefined||b.dataset.direction){handleGameClick(b);return;}
 const a=b.dataset.action;
 if(a==='home'){state.page='home';render();}
 else if(a==='records'){state.page='records';render();}
 else if(a==='start'){state.page='game';state.countdown=3;state.game=null;render();}
 else if(a==='quit'){if(confirm('要结束本次训练并返回模块吗？')){state.page='detail';state.countdown=null;render();}}
 else if(a==='retry'){state.page='game';state.countdown=3;state.game=null;render();}
 else if(a==='detail'){state.page='detail';render();}
 else if(a==='clear-records'){if(confirm('确定清空这台设备上的训练记录吗？')){history=[];save();render();}}
});
render();
