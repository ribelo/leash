#!/usr/bin/env python3
"""Read-only covered-click observer around the unchanged existing L53 harness.
No mission, goal, model, config, action or retry changes. Capture before tab closes.
"""
import importlib.util
from pathlib import Path

repo = Path('/home/ribelo/projects/ribelo/leash')
spec = importlib.util.spec_from_file_location('l53', repo / 'scripts/live-acceptance-l53.py')
l53 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(l53)
original_cli = l53.Gate.cli

# Authored inspection code, never derived from a model response. Points come from DOM.
INSPECT = r"""
const describe = e => {
  if (!e) return null;
  const css = getComputedStyle(e), r = e.getBoundingClientRect();
  return {tag:e.tagName,id:e.id,class:e.className?.toString(),role:e.getAttribute('role'),
    ariaLabel:e.getAttribute('aria-label'),text:(e.innerText||'').slice(0,2000),
    outerHTML:e.outerHTML.slice(0,5000),rect:{x:r.x,y:r.y,width:r.width,height:r.height},
    css:{position:css.position,zIndex:css.zIndex,pointerEvents:css.pointerEvents,
      transform:css.transform,visibility:css.visibility,opacity:css.opacity}};
};
const candidates = [...document.querySelectorAll('a[href],button,[role="link"],[role="button"]')]
  .filter(e => /explore/i.test((e.getAttribute('aria-label')||'')+' '+(e.innerText||'')))
  .map(e => {
    const css=getComputedStyle(e), rect=[...e.getClientRects()].find(r=>r.width>0&&r.height>0);
    if(!rect) return {target:describe(e),noBox:true};
    const number=k=>parseFloat(css[k])||0;
    let x=(rect.left+number('borderLeftWidth')+number('paddingLeft')+
           rect.right-number('borderRightWidth')-number('paddingRight'))/2;
    let y=(rect.top+number('borderTopWidth')+number('paddingTop')+
           rect.bottom-number('borderBottomWidth')-number('paddingBottom'))/2;
    let pointSource='first nonempty client rect content-center; no transform expected';
    if(e.getBoxQuads){const q=e.getBoxQuads({box:'content'})[0];if(q){
      x=(q.p1.x+q.p2.x+q.p3.x+q.p4.x)/4;y=(q.p1.y+q.p2.y+q.p3.y+q.p4.y)/4;
      pointSource='first content quad average, matching Actions.centre';}}
    const covering=document.elementFromPoint(x,y);
    const bx=rect.left+rect.width/2,by=rect.top+rect.height/2;
    return {target:describe(e),operatorIdentity:window.__leashOperatorIds?.nodes.get(e),
      clickPoint:{x,y,source:pointSource},covering:describe(covering),
      hitIsTargetOrDescendant:!!covering&&(covering===e||e.contains(covering)),
      borderCenter:{x:bx,y:by,covering:describe(document.elementFromPoint(bx,by))},
      ancestors:covering?[...function*(n){for(let i=0;n&&i<5;i++,n=n.parentElement)yield describe(n);}(covering)]:[]};
  });
return {url:location.href,title:document.title,timeUnixMs:Date.now(),performanceMs:performance.now(),
  viewport:{width:innerWidth,height:innerHeight,scrollX,scrollY},candidates};
"""

def observed_cli(self, name, *args, **kwargs):
    result = original_cli(self, name, *args, **kwargs)
    reply, code, record = result
    if name == 'drive' and self.args.gate == 'flights' and 'covered at its click point' in str(reply):
        stage = kwargs.get('label', 'covered').rsplit('/', 1)[0]
        tab = args[args.index('--tab') + 1]
        self.save(stage + '/covered-click/failure-context.json', {
            'reason': reply.get('reason') or reply.get('message'),
            'last_operator_steps': reply.get('operator_steps', [])[-2:],
            'observation_only': True, 'mission_retry': False})
        original_cli(self, 'eval', tab, INSPECT, label=stage + '/covered-click/element-from-point')
        original_cli(self, 'shot', tab, str(self.evidence / stage / 'covered-click/page.png'),
                     label=stage + '/covered-click/screenshot')
    return result

l53.Gate.cli = observed_cli
raise SystemExit(l53.main())
