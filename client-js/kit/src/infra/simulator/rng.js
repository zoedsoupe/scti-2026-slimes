// PRNG determinístico do simulador (mulberry32). Interface pura:
// cada chamada devolve [valor, novoRng], espelhando :rand.uniform_s.
// ponytail: não é o exsss do Elixir; as partidas locais só precisam ser
// determinísticas em relação à própria seed. A paridade com o servidor é
// garantida pelas fixtures golden, que evitam cara-ou-coroa (ver
// test/parity_test.js).

export function seedRng(a, b = 0, c = 0) {
  let s = (a * 2654435761 + b * 2246822519 + c * 3266489917) >>> 0;
  if (s === 0) s = 0x9e3779b9;
  return { s };
}

const nextFloat = ({ s }) => {
  s = (s + 0x6d2b79f5) >>> 0;
  let t = s;
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  const f = ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  return [f, { s }];
};

// inteiro em 1..n, como :rand.uniform(n)
export function uniformInt(rng, n) {
  const [f, next] = nextFloat(rng);
  return [Math.floor(f * n) + 1, next];
}

// float em [0,1), como :rand.uniform()
export function uniform(rng) {
  return nextFloat(rng);
}
