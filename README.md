# UParReči

Modernna obrazovna platforma na srpskom jeziku, izgrađena pomoću React + Vite + Supabase i spremna za Vercel i Netlify.

## Šta je uključeno

- Registracija, prijava, Google OAuth, reset lozinke i trajna Supabase sesija.
- Jedinstvena korisnička imena (case-insensitive ograničenje u bazi).
- Objavljivanje, izmena i brisanje školskih materijala.
- PDF i naslovne slike u Supabase Storage.
- Profili, pretraga, filtriranje, sortiranje, sviđanja, komentari, prijave i čuvanje materijala.
- Tamna/svetla tema, izbor srpskog/engleskog jezika, responsive UI, skeletoni i 404 stranica.
- Podešavanja profila, profilna slika i promena korisničkog imena najviše jednom u 14 dana (server-side trigger).
- Podrška za 9. razred osnovne škole.
- Admin prikaz za prijave i osnovnu statistiku; administratorska prava se dodeljuju isključivo ručno u SQL-u.
- RLS pravila u `supabase/schema.sql`.

## 1. Lokalno pokretanje

Potrebni su Node.js 20+ i npm.

```bash
npm install
cp .env.example .env
```

Otvori `.env` i upiši:

```env
VITE_SUPABASE_URL=https://TVOJ-PROJEKAT.supabase.co
VITE_SUPABASE_ANON_KEY=tvoj-anon-ili-publishable-kljuc
```

Zatim:

```bash
npm run dev
```

Vite će prikazati lokalnu adresu, najčešće `http://localhost:5173`.

## 2. Kreiranje Supabase projekta i baze

1. Otvori https://supabase.com/dashboard i izaberi **New project**.
2. Sačuvaj database password na sigurnom mestu.
3. U projektu otvori **SQL Editor → New query**.
4. Kopiraj ceo sadržaj `supabase/schema.sql`, pokreni skriptu i proveri da li su tabele kreirane.
5. U **Project Settings → API** pronađi Project URL i anon/public ili publishable ključ. To su vrednosti za Vite promenljive.
6. U **Authentication → URL Configuration** podesi:
   - Site URL: tvoj Netlify URL, npr. `https://uparreci.netlify.app`
   - Redirect URLs: `http://localhost:5173/**` i `https://uparreci.netlify.app/**`
   - Ako koristiš sopstveni domen, dodaj i njega.

## 3. Google OAuth

1. U Google Cloud Console otvori ili napravi projekat.
2. U **APIs & Services → OAuth consent screen** podesi naziv aplikacije, email za podršku i potrebne podatke. Tokom testiranja dodaj test korisnike.
3. U **Credentials → Create credentials → OAuth client ID** izaberi **Web application**.
4. U **Authorized redirect URIs** dodaj tačan callback URL prikazan u Supabase:  
   `https://TVOJ-PROJEKAT.supabase.co/auth/v1/callback`
5. Kopiraj Google Client ID i Client Secret.
6. U Supabase otvori **Authentication → Providers → Google**, uključi Google i unesi oba podatka.
7. Sačuvaj podešavanja. Google Client Secret se unosi samo u Supabase, nikada u `.env` ili frontend.
8. U Supabase URL Configuration dodaj localhost i Netlify redirect adrese kao u prethodnom odeljku.

**Prvi Google login / username:** Ako Google nalog nema username metapodatak, profil se kreira sa praznim username poljem i aplikacija prikazuje obavezni onboarding ekran. Korisnik bira ime, a RPC funkcija i jedinstveni indeks proveravaju zauzetost pre čuvanja. Ne dodeljuje se automatsko, neželjeno korisničko ime.

## 4. Vercel deploy

1. Uvezi GitHub repository u Vercel.
2. Framework Preset: Vite; Root Directory: `./`.
3. Build Command: `npm run build`; Output Directory: `dist`; Install Command: `npm install`.
4. U Project Settings → Environment Variables dodaj `VITE_SUPABASE_URL` i `VITE_SUPABASE_ANON_KEY`.
5. `vercel.json` već podešava SPA rewrite; nakon promena env varijabli pokreni novi deployment.
6. U Supabase Authentication → URL Configuration postavi produkcioni Site URL i dozvoljene redirect URL-ove.

## 5. Netlify deploy

1. Postavi projekat u GitHub repository.
2. U Netlify izaberi **Add new site → Import an existing project** i poveži repository.
3. Build command: `npm run build`; Publish directory: `dist`. `netlify.toml` već sadrži ova podešavanja i SPA redirect.
4. U Netlify **Site configuration → Environment variables** dodaj:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_ANON_KEY`
5. Pokreni novi deploy nakon dodavanja promenljivih.
6. Vrati se u Supabase Authentication URL Configuration i dodaj tačan Netlify domen u Redirect URLs, a Site URL postavi na produkcioni domen.
7. Proveri Google OAuth na objavljenom domenu.

## 6. Dodela administratora

Prijavi se običnim nalogom, pa u Supabase SQL Editor-u kao vlasnik projekta pokreni:

```sql
update public.profiles
set role = 'admin'
where username = 'TVOJE_TACNO_KORISNICKO_IME';
```

Ne postoji javna registracija administratora. RLS proverava `role='admin'` na serveru.

## 7. Bezbednost i važne napomene

- U frontend ide samo Supabase URL i anon/publishable ključ. To je javni ključ namenjen za RLS-zaštićene pozive.
- **Nikada** ne stavljaj `service_role` ključ u Vite promenljive ili GitHub.
- Pokreni SQL skriptu pre korišćenja sajta.
- U Supabase Storage proveri ograničenja veličine i MIME tipova za `materials`, `covers` i `avatars`.
- RLS štiti redove; administratorska uloga se dodeljuje samo kroz pouzdan SQL/admin proces.
- Za produkciju preporučujemo rate limiting komentara/prijava preko Edge Function ili API gateway, CAPTCHA na registraciji i proveru autentičnosti sadržaja.
- Slike i PDF fajlovi se čuvaju u Supabase Storage, a ne u localStorage.
- Pre objave proveri da korisnici imaju pravo da dele tekstove i fajlove koje postavljaju.

## 8. Provera build-a

```bash
npm install
npm run build
```

Ako se build završi bez greške, produkcioni fajlovi su u `dist/`.

## 9. Struktura projekta

```text
uparreci/
├── index.html
├── package.json
├── vite.config.js
├── netlify.toml
├── .env.example
├── README.md
├── src/
│   ├── main.jsx
│   ├── App.jsx
│   ├── styles.css
│   └── lib/
│       ├── supabase.js
│       └── text.js
└── supabase/
    ├── schema.sql
    └── migrations/
        └── 20261125_profile_grade9_username_cooldown.sql
```


## Postojeća baza: obavezna migracija

Ako je Supabase baza već kreirana, pokreni `supabase/migrations/20261125_profile_grade9_username_cooldown.sql` u Supabase SQL Editor-u. Ona dodaje 9. razred osnovne škole i server-side ograničenje promene korisničkog imena na jednom u 14 dana. Za potpuno novu bazu dovoljno je pokrenuti ažurirani `supabase/schema.sql`.

## Pravna priprema pre javnog lansiranja

Stranice `/privatnost` i `/uslovi` su početni nacrti, a ne pravno mišljenje niti potvrda usklađenosti. Pre javnog lansiranja popuni identitet i kontakt rukovaoca, stvarne svrhe i pravne osnove obrade, rokove čuvanja, obrađivače i međunarodne prenose podataka, postupak za zahteve korisnika, kolačiće/analitiku, pravila o uzrastu i saglasnosti roditelja/staratelja gde je primenljivo. Proveri zahteve Crne Gore i eventualno GDPR ako ciljaš korisnike iz EU. Dodaj stvarnu kontakt adresu i proceduru za prijavu autorskih prava. Nemoj objavljivati dok ovo ne pregleda kvalifikovani pravni stručnjak.
