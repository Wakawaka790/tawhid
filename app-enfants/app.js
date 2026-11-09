/* ═══════════════════════════════════════════════════════════
   Le Jardin du Tawhid — application interactive
   4 modules : Jardin (progression + révision espacée),
   Les 8 clés (quête), Détective (discrimination),
   Compagnon (questions sourcées sur le livre).
   Aucune donnée ne quitte le navigateur.
   ═══════════════════════════════════════════════════════════ */

'use strict';

const CLE_STOCKAGE = 'jardin-tawhid-v1';
const DELAIS = [1, 3, 7, 21];      // jours entre deux révisions
const JOUR = 86400000;

let DATA = { lecons: [], cles: [], detective: {}, compagnon: {} };
let ETAT = {
  lecons: {},      // { n: { box, next } }
  cles: [],        // ids des clés forgées
  scenes: {},      // { sceneId: { rep: { indiceIndex: verdict }, score } }
  voix: false,
  petits: false
};
let sceneEnCours = null;

/* ─────────── Utilitaires ─────────── */
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
const ech = (s) => String(s).replace(/[&<>"']/g, (c) =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const sansAccent = (s) => String(s).toLowerCase()
  .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
  .replace(/[^a-z0-9\s]/g, ' ').replace(/\s+/g, ' ').trim();

function charger() {
  try { Object.assign(ETAT, JSON.parse(localStorage.getItem(CLE_STOCKAGE) || '{}')); }
  catch (e) { /* première visite */ }
}
function sauver() {
  try { localStorage.setItem(CLE_STOCKAGE, JSON.stringify(ETAT)); } catch (e) { /* mode privé */ }
}

function toast(msg) {
  const t = $('#toast');
  t.textContent = msg; t.hidden = false;
  clearTimeout(toast._t);
  toast._t = setTimeout(() => { t.hidden = true; }, 2600);
}

function parler(texte) {
  if (!('speechSynthesis' in window)) return;
  window.speechSynthesis.cancel();
  const u = new SpeechSynthesisUtterance(texte.replace(/[«»]/g, ''));
  u.lang = 'fr-FR'; u.rate = 0.95; u.pitch = 1.05;
  window.speechSynthesis.speak(u);
}
function lire(texte) { if (ETAT.voix) parler(texte); }

/* ─────────── Progression ─────────── */
const stats = () => {
  const maintenant = Date.now();
  let apprises = 0, aReviser = 0;
  DATA.lecons.forEach((l) => {
    const p = ETAT.lecons[l.n];
    if (!p) return;
    apprises++;
    if (p.next && p.next <= maintenant) aReviser++;
  });
  return { apprises, aReviser, reste: DATA.lecons.length - apprises };
};

function validerLecon(n) {
  const p = ETAT.lecons[n] || { box: -1 };
  const box = Math.min(p.box + 1, 4);
  ETAT.lecons[n] = { box, next: box >= 4 ? null : Date.now() + DELAIS[box] * JOUR };
  sauver();
  rendreJardin();
}

/* ─────────── Arbre SVG ─────────── */
function rendreArbre() {
  const svg = $('#arbre');
  const { apprises } = stats();
  const total = DATA.lecons.length || 76;
  const ratio = apprises / total;
  const N = 15;
  const remplis = Math.round(ratio * N);

  let feuilles = '';
  for (let i = 0; i < N; i++) {
    const a = i * 2.39996;
    const r = 8.6 * Math.sqrt(i + 0.6);
    const cx = 160 + r * Math.cos(a);
    const cy = 92 + r * Math.sin(a) * 0.82;
    const plein = i < remplis;
    feuilles += `<circle cx="${cx.toFixed(1)}" cy="${cy.toFixed(1)}" r="${(16 - i * 0.15).toFixed(1)}"
      fill="${plein ? '#17786c' : '#ded7c6'}" opacity="${plein ? 0.92 : 0.7}"
      stroke="${plein ? '#0f4c45' : '#cfc7b4'}" stroke-width="1"/>`;
  }
  for (let i = 0; i < N; i++) {
    if (i >= remplis) continue;
    const a = i * 2.39996;
    const r = 8.6 * Math.sqrt(i + 0.6);
    const cx = 160 + r * Math.cos(a), cy = 92 + r * Math.sin(a) * 0.82;
    feuilles += `<circle cx="${cx.toFixed(1)}" cy="${cy.toFixed(1)}" r="2.6" fill="#c9a227" opacity=".85"/>`;
  }

  svg.innerHTML = `
    <ellipse cx="160" cy="228" rx="74" ry="9" fill="#0f4c45" opacity=".13"/>
    <path d="M154 228 L152 150 Q160 120 168 150 L166 228 Z" fill="#7a5a34"/>
    <path d="M160 168 L128 140" stroke="#7a5a34" stroke-width="7" stroke-linecap="round"/>
    <path d="M160 160 L196 136" stroke="#7a5a34" stroke-width="7" stroke-linecap="round"/>
    <path d="M160 186 L136 190" stroke="#7a5a34" stroke-width="5" stroke-linecap="round"/>
    <path d="M160 182 L188 184" stroke="#7a5a34" stroke-width="5" stroke-linecap="round"/>
    ${feuilles}
    <text x="160" y="248" text-anchor="middle" font-size="13" fill="#6d7a77"
      font-family="system-ui">${apprises} / ${total} leçons</text>`;
}

/* ─────────── Jardin : branches et feuilles ─────────── */
function etatFeuille(n) {
  const p = ETAT.lecons[n];
  if (!p) return { cls: '', label: 'À découvrir' };
  if (p.next && p.next <= Date.now()) return { cls: 'reviser', label: 'À réviser' };
  if (p.box >= 4) return { cls: 'apprise', label: 'Maîtrisée ✦' };
  return { cls: 'apprise', label: 'Apprise' };
}

function rendreJardin() {
  const { apprises, aReviser, reste } = stats();
  $('#st-appris').textContent = apprises;
  $('#st-reviser').textContent = aReviser;
  $('#st-reste').textContent = reste;
  $('#st-bar').style.width = (apprises / DATA.lecons.length * 100).toFixed(1) + '%';
  const rev = $('#btn-revision');
  rev.disabled = aReviser === 0;
  $('#rev-count').textContent = aReviser ? `(${aReviser})` : '';
  rendreArbre();
  rendreStatsParents();

  const conteneur = $('#branches');
  conteneur.innerHTML = '';

  DATA.branches.forEach((br) => {
    const lecons = DATA.lecons.filter((l) => l.branche === br.id);
    const faites = lecons.filter((l) => ETAT.lecons[l.n]).length;
    const wrap = document.createElement('div');
    wrap.className = 'branche';
    wrap.innerHTML = `
      <button class="branche-head" aria-expanded="false">
        <span class="branche-dot" style="background:${br.couleur}"></span>
        <span class="branche-nom">${ech(br.nom)}</span>
        <span class="branche-count">${faites} / ${lecons.length}</span>
        <span class="branche-chev">›</span>
      </button>
      <div class="feuilles" hidden></div>`;

    const head = $('.branche-head', wrap);
    const corps = $('.feuilles', wrap);
    head.addEventListener('click', () => {
      const ouvert = wrap.classList.toggle('open');
      corps.hidden = !ouvert;
      head.setAttribute('aria-expanded', String(ouvert));
      if (ouvert && !corps.dataset.rempli) { remplirFeuilles(corps, lecons); corps.dataset.rempli = '1'; }
    });
    if (faites > 0 || br.id === 1) {                    // ouvrir la 1ʳᵉ branche par défaut
      wrap.classList.add('open'); corps.hidden = false;
      remplirFeuilles(corps, lecons); corps.dataset.rempli = '1';
    }
    conteneur.appendChild(wrap);
  });
}

function remplirFeuilles(corps, lecons) {
  corps.innerHTML = '';
  lecons.forEach((l) => {
    const st = etatFeuille(l.n);
    const b = document.createElement('button');
    b.className = 'feuille ' + st.cls;
    b.title = st.label;
    b.innerHTML = `<span class="n">${l.n}</span> ${ech(l.titre)}`;
    b.addEventListener('click', () => ouvrirLecon(l));
    corps.appendChild(b);
  });
}

/* ─────────── Leçon (modale) ─────────── */
function ouvrirLecon(l) {
  const branche = DATA.branches.find((b) => b.id === l.branche);
  const st = etatFeuille(l.n);
  const question = l.question;

  const html = `
    <span class="lecon-tag n${l.niveau}">Leçon ${l.n} · niveau ${l.niveau}</span>
    <h2>${ech(l.titre)}</h2>
    <p class="page">${ech(branche ? branche.nom : '')} — page ${l.page} du livre</p>

    ${l.histoire ? `<div class="bloc">
        <h4>L'histoire</h4><p>${ech(l.histoire)}</p></div>` : ''}

    <div class="bloc">
      <h4>Ce qu'il faut retenir</h4><p>${ech(l.notion)}</p>
    </div>

    <div class="bloc qcm">
      <h4>Petite question</h4>
      <p style="margin:0 0 4px">${ech(question.q)}</p>
      <div id="opts"></div>
      <div id="expl"></div>
    </div>

    <div class="defi">
      <h4 style="margin:0 0 4px;font-size:13px;letter-spacing:.6px;color:#c9a227">MON DÉFI DU JOUR</h4>
      <p style="margin:0">${ech(l.defi)}</p>
    </div>

    <div class="modal-actions">
      <button class="btn" id="btn-lire">🔊 Écouter la leçon</button>
      <button class="btn primary" id="btn-compris" disabled>
        ${st.cls === 'apprise' ? 'Je révise, c\'est bon !' : 'J\'ai compris et j\'ai fait le défi'}
      </button>
      <span id="etat-lbl" style="align-self:center;font-size:13px;color:#6d7a77">${ech(st.label)}</span>
    </div>`;

  $('#modal-body').innerHTML = html;
  $('#modal').hidden = false;

  const opts = $('#opts');
  question.o.forEach((texte, i) => {
    const b = document.createElement('button');
    b.className = 'opt';
    b.textContent = texte;
    b.addEventListener('click', () => {
      $$('.opt', opts).forEach((o) => { o.classList.remove('juste', 'faux'); o.disabled = true; });
      if (i === question.r) { b.classList.add('juste'); toast('Bravo !'); }
      else { b.classList.add('faux'); $$('.opt', opts)[question.r].classList.add('juste'); }
      $('#expl').innerHTML = `<div class="expl"><b>Explication.</b> ${ech(question.ex)}</div>`;
      $('#btn-compris').disabled = false;
      lire(question.ex);
    });
    opts.appendChild(b);
  });

  $('#btn-lire').addEventListener('click', () =>
    parler(`${l.titre}. ${l.histoire || ''} ${l.notion} Question : ${question.q}`));

  $('#btn-compris').addEventListener('click', () => {
    validerLecon(l.n);
    $('#modal').hidden = true;
    toast(l.n === 76 ? 'Mâcha Allâh, le jardin est complet !' : 'Leçon validée — à réviser bientôt.');
  });

  if (ETAT.petits || ETAT.voix) parler(`${l.titre}. ${l.notion}`);
}

function fermerModal() { $('#modal').hidden = true; if ('speechSynthesis' in window) window.speechSynthesis.cancel(); }

/* ─────────── Révision rapide ─────────── */
function revisionRapide() {
  const maintenant = Date.now();
  const liste = DATA.lecons.filter((l) => ETAT.lecons[l.n] && ETAT.lecons[l.n].next && ETAT.lecons[l.n].next <= maintenant);
  if (!liste.length) return;
  ouvrirLecon(liste[0]);
}

/* ─────────── Espace parents ─────────── */
function rendreStatsParents() {
  const { apprises, aReviser, reste } = stats();
  const cles = ETAT.cles.length;
  const scenes = Object.values(ETAT.scenes);
  const scoreDet = scenes.reduce((a, s) => a + (s.score || 0), 0);
  const maxDet = scenes.reduce((a, s) => a + (s.total || 0), 0);
  const maitrisees = DATA.lecons.filter((l) => ETAT.lecons[l.n] && ETAT.lecons[l.n].box >= 4).length;
  $('#parents-stats').innerHTML = `
    <li><strong>${apprises}</strong> leçons commencées, dont <strong>${maitrisees}</strong> maîtrisées</li>
    <li><strong>${aReviser}</strong> leçons à réviser aujourd'hui · <strong>${reste}</strong> leçons non découvertes</li>
    <li><strong>${cles} / 8</strong> clés forgées</li>
    <li>Enquêtes : <strong>${scoreDet} / ${maxDet}</strong> bons verdicts</li>`;
}

/* ─────────── Les 8 clés ─────────── */
function rendreCles() {
  const d = DATA.cles;
  $('#cles-intro').textContent = d.consigne;
  const conteneur = $('#cles');
  conteneur.innerHTML = '';
  d.cles.forEach((c) => {
    const forgee = ETAT.cles.includes(c.id);
    const el = document.createElement('button');
    el.className = 'cle' + (forgee ? ' forged' : '');
    el.innerHTML = `
      ${forgee ? '<span class="badge">Forgée</span>' : ''}
      <div class="cle-ico">${forgee ? '⚿' : '🔒'}</div>
      <h3>${c.id}. ${ech(c.nom)}</h3>
      <p>${ech(c.rappel)}</p>`;
    el.addEventListener('click', () => ouvrirCle(c));
    conteneur.appendChild(el);
  });
  const toutes = ETAT.cles.length === d.cles.length;
  $('#cles-door').classList.toggle('open', toutes);
  $('#door-msg').textContent = toutes
    ? 'Mâcha Allâh ! Les 8 clés sont forgées — la porte est ouverte.'
    : `Encore ${d.cles.length - ETAT.cles.length} clé(s) à forger.`;
}

function ouvrirCle(c) {
  const html = `
    <span class="lecon-tag">Clé ${c.id} — leçon 2, p. 14</span>
    <h2>${ech(c.nom)}</h2>
    <div class="bloc"><h4>Rappel</h4><p>${ech(c.rappel)}</p></div>
    <div class="bloc qcm">
      <h4>Forger la clé</h4>
      <p style="margin:0 0 4px">${ech(c.q)}</p>
      <div id="opts"></div><div id="expl"></div>
    </div>
    <div class="modal-actions">
      <button class="btn" id="btn-lire">🔊 Écouter</button>
      <button class="btn primary" id="btn-forge" disabled>${ETAT.cles.includes(c.id) ? 'Clé déjà forgée' : 'Forger cette clé'}</button>
    </div>`;
  $('#modal-body').innerHTML = html;
  $('#modal').hidden = false;

  const opts = $('#opts');
  c.o.forEach((texte, i) => {
    const b = document.createElement('button');
    b.className = 'opt'; b.textContent = texte;
    b.addEventListener('click', () => {
      $$('.opt', opts).forEach((o) => { o.classList.remove('juste', 'faux'); o.disabled = true; });
      if (i === c.r) { b.classList.add('juste'); $('#btn-forge').disabled = false; toast('Exact !'); }
      else { b.classList.add('faux'); $$('.opt', opts)[c.r].classList.add('juste'); }
      $('#expl').innerHTML = `<div class="expl"><b>Explication.</b> ${ech(c.ex)}</div>`;
      lire(c.ex);
    });
    opts.appendChild(b);
  });
  $('#btn-lire').addEventListener('click', () => parler(`${c.nom}. ${c.rappel} ${c.q}`));

  $('#btn-forge').addEventListener('click', () => {
    if (!ETAT.cles.includes(c.id)) { ETAT.cles.push(c.id); sauver(); }
    $('#modal').hidden = true;
    rendreCles();
    toast(ETAT.cles.length === 8 ? 'Les 8 clés sont forgées !' : 'Clé forgée !');
  });
}

/* ─────────── Détective ─────────── */
function rendreScenes() {
  const d = DATA.detective;
  $('#det-intro').textContent = d.consigne;
  const conteneur = $('#scenes');
  conteneur.innerHTML = '';
  d.scenes.forEach((s) => {
    const st = ETAT.scenes[s.id];
    const el = document.createElement('button');
    el.className = 'scene-card';
    el.innerHTML = `<span class="sym">${s.symbol}</span>
      <span class="t">${ech(s.titre)}</span><br>
      <span class="sc">${st ? `${st.score} / ${st.total}` : `${s.indices.length} indices`}</span>`;
    el.addEventListener('click', () => ouvrirScene(s));
    conteneur.appendChild(el);
  });
}

function ouvrirScene(s) {
  sceneEnCours = s;
  const st = ETAT.scenes[s.id] || { rep: {}, score: 0, total: s.indices.length };
  ETAT.scenes[s.id] = st;
  const V = DATA.detective.verdicts;

  let html = `<div class="scene-jeu-titre">
      <span class="sym">${s.symbol}</span>
      <div><h3>${ech(s.titre)}</h3>
      <p style="margin:0;color:#6d7a77;font-size:13.5px">Classe chaque indice. ${st.score} / ${st.total}</p></div>
    </div>`;

  s.indices.forEach((ind, i) => {
    const rep = st.rep[i];
    const juste = rep === ind.v;
    html += `<div class="indice ${rep ? (juste ? 'ok' : 'ko') : ''}" data-i="${i}">
      <div class="txt">${ech(ind.t)}</div>
      <div class="choix">
        ${Object.entries(V).map(([k, v]) =>
      `<button class="vbtn" data-v="${k}" ${rep ? 'disabled' : ''}
            style="${rep && k === ind.v ? 'background:#e8f3ec;border-color:#2e8b57;font-weight:700' : ''}
                   ${rep && k === rep && !juste ? 'background:#fbe9ec;border-color:#b3233c' : ''}">
            ${v.emoji} ${v.label}</button>`).join('')}
      </div>
      ${rep ? `<p class="ex"><b>${juste ? 'Bien vu.' : 'Attention.'}</b> ${ech(ind.ex)}</p>` : ''}
    </div>`;
  });

  const fini = Object.keys(st.rep).length === s.indices.length;
  html += `<div class="score-box">
      <div class="g">${st.score} / ${st.total}</div>
      <p style="margin:4px 0 12px;color:#6d7a77">${fini
      ? (st.score === st.total ? 'Enquête parfaite, Mâcha Allâh !' : 'Relis les explications et réessaie.')
      : 'Trouve le bon verdict pour chaque indice.'}</p>
      <button class="btn small" id="btn-rejouer">Recommencer l'enquête</button>
    </div>`;

  $('#scene-jeu').innerHTML = html;

  $$('#scene-jeu .vbtn').forEach((b) => b.addEventListener('click', () => {
    const i = +b.closest('.indice').dataset.i;
    const st2 = ETAT.scenes[s.id];
    if (st2.rep[i] !== undefined) return;
    st2.rep[i] = b.dataset.v;
    if (b.dataset.v === s.indices[i].v) st2.score++;
    else st2.score = Math.max(0, st2.score);
    sauver(); ouvrirScene(s); rendreScenes(); rendreStatsParents();
  }));
  $('#btn-rejouer').addEventListener('click', () => {
    ETAT.scenes[s.id] = { rep: {}, score: 0, total: s.indices.length };
    sauver(); ouvrirScene(s); rendreScenes();
  });
  $('#scene-jeu').scrollIntoView({ behavior: 'smooth', block: 'start' });
}

/* ─────────── Compagnon ─────────── */
function rendreCompagnon() {
  $('#comp-avert').textContent = DATA.compagnon.avertissement;
  const chips = $('#q-chips');
  chips.innerHTML = '';
  DATA.compagnon.questions.slice(0, 10).forEach((q) => {
    const b = document.createElement('button');
    b.className = 'chip-q'; b.textContent = q.q;
    b.addEventListener('click', () => { $('#q').value = q.q; repondre(q.q); });
    chips.appendChild(b);
  });
}

function repondre(question) {
  const qn = sansAccent(question);
  const mots = qn.split(' ').filter((m) => m.length > 2);
  const resultats = DATA.compagnon.questions.map((e) => {
    let score = 0;
    e.mots.forEach((m) => { if (qn.includes(sansAccent(m))) score += 3; });
    sansAccent(e.q).split(' ').forEach((m) => { if (m.length > 2 && mots.includes(m)) score += 1; });
    sansAccent(e.a).split(' ').forEach((m) => { if (m.length > 4 && mots.includes(m)) score += 0.4; });
    return { e, score };
  }).sort((a, b) => b.score - a.score);

  const zone = $('#reponse');
  const meilleur = resultats[0];

  if (!question.trim() || meilleur.score < 2.5) {
    zone.innerHTML = `<div class="rep">
      <h3>Je ne trouve pas cela dans le livre</h3>
      <p>Le compagnon ne répond qu'à partir du livre. Pour cette question, le mieux est de la poser
      à tes parents, à ton professeur, ou à une personne de science.</p>
      <div class="autre"><strong>Essaie plutôt :</strong>
        ${resultats.slice(0, 4).map((r) => `<button data-q="${ech(r.e.q)}">${ech(r.e.q)}</button>`).join('')}
      </div></div>`;
  } else {
    zone.innerHTML = `<div class="rep">
      <h3>${ech(meilleur.e.q)}</h3>
      <p>${ech(meilleur.e.a)}</p>
      <div class="src">Source : <b>${ech(meilleur.e.ref)}</b> du livre
        <em>Leçons de Tawhid — Al-Qawl Al-Mufîd fî Adillat At-Tawhîd</em>.</div>
      <div class="autre"><strong>Questions proches :</strong>
        ${resultats.slice(1, 4).filter((r) => r.score > 1).map((r) => `<button data-q="${ech(r.e.q)}">${ech(r.e.q)}</button>`).join('')}
      </div></div>`;
    lire(meilleur.e.a);
  }
  $$('#reponse button[data-q]').forEach((b) =>
    b.addEventListener('click', () => { $('#q').value = b.dataset.q; repondre(b.dataset.q); }));
}

/* ─────────── Navigation ─────────── */
function rendreTout() {
  rendreJardin(); rendreCles(); rendreScenes(); rendreCompagnon();
}

function init() {
  charger();
  document.body.classList.toggle('petits', !!ETAT.petits);
  $('#btn-petits').setAttribute('aria-pressed', String(!!ETAT.petits));
  $('#btn-voice').setAttribute('aria-pressed', String(!!ETAT.voix));

  $$('.tab').forEach((t) => t.addEventListener('click', () => {
    $$('.tab').forEach((x) => x.classList.remove('active'));
    $$('.view').forEach((x) => x.classList.remove('active'));
    t.classList.add('active');
    $('#view-' + t.dataset.view).classList.add('active');
    $('#scene-jeu').innerHTML = '';
  }));

  $('#btn-voice').addEventListener('click', (e) => {
    ETAT.voix = !ETAT.voix; sauver();
    e.currentTarget.setAttribute('aria-pressed', String(ETAT.voix));
    toast(ETAT.voix ? 'Lecture vocale activée' : 'Lecture vocale désactivée');
  });
  $('#btn-petits').addEventListener('click', (e) => {
    ETAT.petits = !ETAT.petits; sauver();
    document.body.classList.toggle('petits', ETAT.petits);
    e.currentTarget.setAttribute('aria-pressed', String(ETAT.petits));
  });
  $('#btn-revision').addEventListener('click', revisionRapide);
  $('#modal-close').addEventListener('click', fermerModal);
  $('#modal').addEventListener('click', (e) => { if (e.target.id === 'modal') fermerModal(); });
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape') fermerModal(); });
  $('#btn-ask').addEventListener('click', () => repondre($('#q').value));
  $('#q').addEventListener('keydown', (e) => { if (e.key === 'Enter') repondre($('#q').value); });
  $('#btn-reset').addEventListener('click', () => {
    if (confirm('Effacer toute la progression de cet appareil ?')) {
      ETAT.lecons = {}; ETAT.cles = []; ETAT.scenes = {}; sauver(); rendreTout(); toast('Progression réinitialisée');
    }
  });

  /* Outils de test : avancer le temps pour déclencher les révisions */
  const avancerTemps = (jours) => {
    Object.keys(ETAT.lecons).forEach((n) => {
      const p = ETAT.lecons[n];
      if (p && p.next) p.next -= jours * JOUR;
    });
    sauver(); rendreTout();
    const { aReviser } = stats();
    toast(aReviser ? `+${jours} jour(s) — ${aReviser} leçon(s) à réviser` : `+${jours} jour(s) — rien à réviser`);
  };
  $('#btn-jour1').addEventListener('click', () => avancerTemps(1));
  $('#btn-jour7').addEventListener('click', () => avancerTemps(7));
  $('#btn-demo').addEventListener('click', () => {
    DATA.lecons.slice(0, 12).forEach((l, i) => {
      if (!ETAT.lecons[l.n]) ETAT.lecons[l.n] = { box: i % 4, next: Date.now() + (i % 3) * JOUR };
    });
    sauver(); rendreTout(); toast('12 leçons pré-remplies — recharge pour voir les feuilles jaunes');
  });

  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('sw.js').catch(() => { /* pas bloquant */ });
  }

  Promise.all([
    fetch('data/lecons.json').then((r) => r.json()),
    fetch('data/cles.json').then((r) => r.json()),
    fetch('data/detective.json').then((r) => r.json()),
    fetch('data/compagnon.json').then((r) => r.json())
  ]).then(([lecons, cles, det, comp]) => {
    DATA.branches = lecons.branches; DATA.lecons = lecons.lecons;
    DATA.cles = cles; DATA.detective = det; DATA.compagnon = comp;
    rendreTout();
  }).catch((err) => {
    document.querySelector('main').innerHTML =
      `<p style="color:#b3233c">Impossible de charger les données (${ech(err.message)}).
       Ouvre cette page depuis un petit serveur local, par exemple :
       <code>python3 -m http.server</code> dans le dossier <code>app-enfants</code>.</p>`;
  });
}

document.addEventListener('DOMContentLoaded', init);
