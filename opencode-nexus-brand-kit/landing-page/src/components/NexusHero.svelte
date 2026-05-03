<script>
  const stats = [{label:'Active Nodes',value:'128'}, {label:'Connections',value:'512'}, {label:'Uptime',value:'99.9%'}, {label:'Latency',value:'<50ms'}];
</script>
<section class="hero">
  <div class="copy">
    <p class="eyebrow">Agentic network orchestration</p>
    <h1>Orchestrate any grid from <span>anywhere.</span></h1>
    <p class="lead">OpencodeNexus gives you full control over server hubs, agents, tools, and runtime connections with real-time visibility and command-grade reliability.</p>
    <div class="actions"><a href="#get-started">Get Started</a><a class="ghost" href="#docs">View Docs</a></div>
  </div>
  <div class="orb" aria-hidden="true"><div class="x">×</div></div>
  <div class="stats">{#each stats as s}<div><strong>{s.value}</strong><span>{s.label}</span></div>{/each}</div>
</section>
<style>
.hero{position:relative;overflow:hidden;min-height:720px;padding:72px;display:grid;grid-template-columns:1.1fr .9fr;align-items:center;background:radial-gradient(circle at 70% 40%,#1b232d,transparent 35%),#050607;color:white;border-radius:32px;font-family:Inter,system-ui,sans-serif}.eyebrow{color:#22D08A;text-transform:uppercase;letter-spacing:.16em;font-size:.8rem}h1{font-size:clamp(3rem,7vw,6.5rem);line-height:.95;margin:0 0 24px;font-family:Orbitron,Inter,sans-serif}h1 span{color:#22D08A}.lead{font-size:1.15rem;color:#BEC6CE;max-width:660px;line-height:1.7}.actions{display:flex;gap:16px;margin-top:32px}.actions a{background:white;color:#050607;text-decoration:none;padding:14px 22px;border-radius:999px;font-weight:700}.actions .ghost{background:transparent;color:white;border:1px solid #3A424C}.orb{justify-self:center;width:360px;height:360px;border-radius:50%;border:4px dashed #BEC6CE;display:grid;place-items:center;box-shadow:0 0 80px rgba(34,208,138,.18);animation:spin 18s linear infinite}.orb:before{content:"";position:absolute;width:520px;height:520px;border-radius:50%;background:repeating-conic-gradient(from 0deg,#22D08A 0 2deg,transparent 2deg 20deg);opacity:.35}.x{font-size:180px;font-weight:900;animation:spin 18s linear reverse infinite}.stats{position:absolute;left:72px;right:72px;bottom:48px;display:grid;grid-template-columns:repeat(4,1fr);gap:16px;background:rgba(255,255,255,.04);border:1px solid #2C323A;border-radius:24px;padding:24px}.stats strong{font-size:2rem;display:block}.stats span{color:#BEC6CE}@keyframes spin{to{transform:rotate(360deg)}}@media(max-width:900px){.hero{grid-template-columns:1fr;padding:32px}.orb{width:240px;height:240px}.stats{position:static;grid-template-columns:repeat(2,1fr);margin-top:32px}}
</style>
