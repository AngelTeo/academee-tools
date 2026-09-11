(()=>{
const STATE={progress:{dept:'',slot:''},records:{dept:'',slot:''},analysis:{dept:'',slot:''}};
let catalog=[],srtTeachers=[],legacyClasses=[];
const E=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const order=['SRK','GAK','ATC','SRT'];
const deptColor={SRK:'#C45C5C',GAK:'#E8A04E',ATC:'#7AB05A',SRT:'#8B6CAE'};
function norm(x){return String(x||'').replace(/^SRT[._-]?/,'').replace(/_/g,'.');}
function resolveVisitClass(x){if(!x)return x;const h=legacyClasses.find(c=>String(c.id)===String(x));return h?(h.display_name||h.class_name||h.code||x):x;}
function teacherFor(c){if(!c||c.dept!=='SRT')return '';const lvl='SRT.'+String(c.level||'').replace(/^SRT\.?/,'');const h=srtTeachers.find(t=>t.slot===c.slot&&(t.level===lvl||t.level===c.level));return h?h.teacher:'';}
async function loadCatalog(){
  try{const a=await sb.from('hub_classes').select('id,code,dept,label,slot,level,status').eq('status','active');if(!a.error)catalog=a.data||[];}catch(e){}
  try{const b=await sb.from('classgo_srt').select('slot,level,teacher,subj');if(!b.error)srtTeachers=b.data||[];}catch(e){}
  try{const c=await sb.from('classes').select('*');if(!c.error)legacyClasses=c.data||[];}catch(e){}
  rows.forEach(r=>r.cls=resolveVisitClass(r.cls));
}
function classesFor(k){const s=STATE[k];if(!s.dept)return[];return catalog.filter(c=>c.dept===s.dept&&(s.dept!=='SRT'||!s.slot||c.slot===s.slot)).sort((a,b)=>String(a.label||a.code).localeCompare(String(b.label||b.code),undefined,{numeric:true}));}
function visitsFor(k){const s=STATE[k];if(!s.dept)return[];return rows.filter(x=>x.dept===s.dept&&(s.dept!=='SRT'||!s.slot||String(x.cls).includes(s.slot)));}
function slots(){return [...new Set(catalog.filter(c=>c.dept==='SRT'&&c.slot).map(c=>c.slot))].sort();}
function mk(text,sub,on,attrs,color){return `<button type="button" class="mg-sel-card${on?' on':''}" ${attrs} style="${on?'--sel:'+color:''}"><b>${E(text)}</b>${sub?`<span>${E(sub)}</span>`:''}</button>`;}
function drawSelector(k){
  const root=document.getElementById('filters-'+k);if(!root)return;const s=STATE[k];
  let h='<div class="mg-step"><div class="mg-step-title">① 部门</div><div class="mg-option-grid">'+order.map(d=>mk(d,catalog.filter(c=>c.dept===d).length+' 班',s.dept===d,`data-k="${k}" data-type="dept" data-val="${d}"`,deptColor[d])).join('')+'</div></div>';
  if(s.dept==='SRT')h+='<div class="mg-step"><div class="mg-step-title">② 时段</div><div class="mg-option-grid">'+slots().map(t=>mk(t.replace('.', ' · '),catalog.filter(c=>c.dept==='SRT'&&c.slot===t).length+' 班',s.slot===t,`data-k="${k}" data-type="slot" data-val="${E(t)}"`,'#8B6C2A')).join('')+'</div></div>';
  root.innerHTML=h;
  root.querySelectorAll('.mg-sel-card').forEach(b=>b.onclick=()=>{const s2=STATE[b.dataset.k];if(b.dataset.type==='dept'){s2.dept=b.dataset.val;s2.slot='';}else{s2.slot=b.dataset.val;}drawSelector(b.dataset.k);renderKey(b.dataset.k);});
}
function stats(label){const vs=rows.filter(x=>norm(x.cls)===norm(label));return{vs,d:vs.filter(x=>x.status==='draft').length,c:vs.filter(x=>x.status==='completed').length,z:vs.filter(x=>x.status==='cancelled').length,obs:[...new Set(vs.map(x=>x.who).filter(Boolean))].join(', ')||'',last:vs.map(x=>x.updated).filter(Boolean).sort().pop()};}
function classCards(k){return classesFor(k).map(c=>{const label=c.label||c.code||c.id,st=stats(label),teacher=teacherFor(c),status=st.d?'未完成':st.c?'已完成':'尚未巡班',klass=st.d?'is-draft':st.c?'is-done':'is-none';return `<div class="mg-progress-card ${klass}"><div class="mg-card-top"><b>${E(label)}</b><span class="mg-status">${E(status)}</span></div>${teacher?`<div class="mg-line"><span>负责</span><strong>${E(teacher)}</strong></div>`:''}${st.obs?`<div class="mg-line"><span>巡班</span><strong>${E(st.obs)}</strong></div>`:''}${st.last?`<div class="mg-last">最后更新 ${E(new Date(st.last).toLocaleString('en-GB'))}</div>`:''}</div>`;}).join('');}
function ready(k){const s=STATE[k];return s.dept&&!(s.dept==='SRT'&&!s.slot);}
function renderKey(k){if(k==='progress')render();else if(k==='records')renderRecords();else renderAnalysis();}
window.render=function(){
  drawSelector('progress');
  if(!ready('progress')){document.getElementById('metrics').innerHTML='';document.getElementById('progress').innerHTML='<div class="empty">请选择部门'+(STATE.progress.dept==='SRT'?'与时段':'')+'。</div>';return;}
  const a=visitsFor('progress'),d=a.filter(x=>x.status==='draft').length,c=a.filter(x=>x.status==='completed').length,p=new Set(a.map(x=>x.who));
  document.getElementById('metrics').innerHTML=`<div class="card metric"><b>${p.size}</b><span>巡班人</span></div><div class="card metric"><b>${d}</b><span>未完成</span></div><div class="card metric"><b>${c}</b><span>已完成</span></div>`;
  document.getElementById('progress').innerHTML='<div class="mg-section-head"><div><b>班级进度</b><span>一眼查看负责人、巡班人和状态</span></div><button class="btn subtle" onclick="loadAll()">↻ 更新</button></div><div class="mg-progress-grid">'+classCards('progress')+'</div>';
};
window.renderRecords=function(){
  drawSelector('records');
  if(!ready('records')){document.getElementById('records').innerHTML='<div class="empty">请选择部门'+(STATE.records.dept==='SRT'?'与时段':'')+'。</div>';return;}
  const q=((document.getElementById('q')||{}).value||'').trim().toLowerCase(),a=visitsFor('records').filter(x=>!q||(x.who+' '+x.dept+' '+x.cls+' '+x.date).toLowerCase().includes(q));
  document.getElementById('records').innerHTML=a.length?'<div class="row h"><div>班级 / 时段</div><div>巡班人</div><div>日期</div><div>Evidence</div><div>状态</div></div>'+a.map(x=>`<div class="row"><b>${E(x.dept+' · '+x.cls)}</b><div>${E(x.who)}</div><div>${E(x.date)}</div><div>${x.nStu} students · ${x.nE} evidence</div><div>${pill(x.status)}</div></div>`).join(''):'<div class="empty">这个范围目前没有巡班记录。</div>';
};
window.renderAnalysis=function(){
  drawSelector('analysis');
  if(!ready('analysis')){document.getElementById('analysis').innerHTML='';document.getElementById('bydept').innerHTML='<div class="empty">请选择部门'+(STATE.analysis.dept==='SRT'?'与时段':'')+'。</div>';return;}
  const a=visitsFor('analysis'),d=a.filter(x=>x.status==='draft').length,c=a.filter(x=>x.status==='completed').length,t=c+d,pct=t?Math.round(c/t*100):0;
  document.getElementById('analysis').innerHTML=`<div class="card metric"><b>${pct}%</b><span>完成率</span></div><div class="card metric"><b>${d}</b><span>未完成</span></div><div class="card metric"><b>${c}</b><span>已完成</span></div>`;
  document.getElementById('bydept').innerHTML='<div class="mg-section-head"><div><b>班级状态汇总</b><span>汇总多次巡班后的班级状态</span></div></div><div class="mg-progress-grid">'+classCards('analysis')+'</div>';
};
const oldGo=window.go;window.go=function(p){oldGo(p);if(STATE[p])drawSelector(p);};
const oldLoad=window.loadAll;window.loadAll=async function(){await oldLoad();await loadCatalog();drawSelector('progress');drawSelector('records');drawSelector('analysis');render();};
})();