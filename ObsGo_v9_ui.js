document.addEventListener('DOMContentLoaded',function(){
  /* One-time cleanup of Owner test artifacts already removed from Production. */
  const deadCloudIds=['23649ae5-c219-4c52-b1d9-b88253b0ac30','e22573c0-2158-4652-9416-54f95beb6bef'];
  let cleaned=false;
  if(state&&Array.isArray(state.drafts)){const n=state.drafts.length;state.drafts=state.drafts.filter(v=>!deadCloudIds.includes(v&&v.cloud_id));cleaned=cleaned||state.drafts.length!==n;}
  if(state&&Array.isArray(state.records)){const n=state.records.length;state.records=state.records.filter(v=>!deadCloudIds.includes(v&&v.cloud_id));cleaned=cleaned||state.records.length!==n;}
  if(state&&state.visit&&deadCloudIds.includes(state.visit.cloud_id)){state.visit=null;cleaned=true;}
  if(cleaned&&typeof save==='function')save(true);

  const oldFinish=finishVisit;
  finishVisit=function(){
    if(state.visit&&state.visit._browseOnly){toast('还没有记录任何观察，不会建立草稿');return;}
    return oldFinish.apply(this,arguments);
  };

  window.obsgoV9BackHome=function(){
    const v=state.visit;
    if(v&&v._browseOnly){
      state.visit=null;
      showScreen('select');renderSelect();
      return;
    }
    /* 已经开始的巡班：回主页面只是导航；现有自动储存机制继续负责资料安全。 */
    showScreen('select');renderSelect();
  };

  const oldRender=renderVisit;
  renderVisit=function(){
    oldRender.apply(this,arguments);
    if(state.visit&&state.visit._browseOnly){
      const m=document.getElementById('visit-meta');
      if(m)m.textContent=state.visit.dateLabel+' · '+state.visit.observer+' · 浏览中 · 尚未开始计时'+(state.visit.curriculumBand?(' · band '+state.visit.curriculumBand):'');
    }
  };

  const b=document.getElementById('btn-start');if(b)b.style.display='none';
  const sm=document.getElementById('start-meta');if(sm)sm.textContent='点班级直接进入巡班；浏览不会建立草稿，第一次记录观察后才开始计时';
  const st=document.getElementById('start-title');if(st)st.textContent='请选择班级进入巡班';

  const back=[...document.querySelectorAll('button.ghost.btn-sm')].find(x=>x.textContent.includes('回主页面'));
  if(back){back.textContent='← 回主页面';back.setAttribute('onclick','obsgoV9BackHome()');back.title='返回班级选择页；只是浏览时不会建立草稿';}

  const saveBtn=document.getElementById('btn-save');if(saveBtn)saveBtn.remove();
  const park=document.getElementById('btn-park');
  if(park){park.textContent='储存并退出';park.title='明确保存当前未完成巡班并返回班级选择页';}
  const finish=document.getElementById('btn-finish-top');
  if(finish)finish.title='正式结束这次巡班并形成 completed Evidence';
});