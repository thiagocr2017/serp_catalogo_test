-- Geografia de Clientes (Decisiones 28, 29, 30):
-- 1. Catalogo de paises (countries) con Costa Rica precargado.
-- 2. Catalogo de provincias (administrative_areas) con las 7 provincias de Costa Rica.
-- 3. Catalogo de ciudades/distritos (cities) con distritos INEC de Costa Rica y autoaprendizaje.
-- 4. customers suma country_code y city.
-- 5. create_customer y update_customer soportan p_country_code y p_city con autoaprendizaje en cities.

create table if not exists public.countries (
  code text primary key,
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.countries enable row level security;
revoke all on public.countries from public, anon, authenticated;
grant select on public.countries to anon, authenticated;

drop policy if exists countries_select_policy on public.countries;
create policy countries_select_policy on public.countries
  for select to anon, authenticated using (true);

insert into public.countries (code, name, is_active)
values ('CR', 'Costa Rica', true)
on conflict (code) do update set name = excluded.name;

create table if not exists public.administrative_areas (
  id uuid primary key default extensions.gen_random_uuid(),
  country_code text not null references public.countries(code) on update cascade,
  code text not null,
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint uq_administrative_areas_code unique (country_code, code),
  constraint uq_administrative_areas_name unique (country_code, name)
);

alter table public.administrative_areas enable row level security;
revoke all on public.administrative_areas from public, anon, authenticated;
grant select on public.administrative_areas to anon, authenticated;

drop policy if exists administrative_areas_select_policy on public.administrative_areas;
create policy administrative_areas_select_policy on public.administrative_areas
  for select to anon, authenticated using (true);

insert into public.administrative_areas (country_code, code, name, is_active)
values
  ('CR', 'SJ', 'San José', true),
  ('CR', 'AL', 'Alajuela', true),
  ('CR', 'CA', 'Cartago', true),
  ('CR', 'HE', 'Heredia', true),
  ('CR', 'GU', 'Guanacaste', true),
  ('CR', 'PU', 'Puntarenas', true),
  ('CR', 'LI', 'Limón', true)
on conflict (country_code, code) do update set name = excluded.name;

create table if not exists public.cities (
  id uuid primary key default extensions.gen_random_uuid(),
  country_code text not null references public.countries(code) on update cascade,
  administrative_area_id uuid references public.administrative_areas(id) on delete set null,
  province_name text not null,
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create unique index if not exists uq_cities_country_province_name
  on public.cities (country_code, lower(btrim(province_name)), lower(btrim(name)));

create index if not exists idx_cities_province_name
  on public.cities (country_code, lower(btrim(province_name)));

alter table public.cities enable row level security;
revoke all on public.cities from public, anon, authenticated;
grant select on public.cities to anon, authenticated;

drop policy if exists cities_select_policy on public.cities;
create policy cities_select_policy on public.cities
  for select to anon, authenticated using (true);

-- ============================================================
-- Precarga de distritos y cabeceras de Costa Rica (INEC)
-- ============================================================

with prov_ids as (
  select id, name from public.administrative_areas where country_code = 'CR'
), raw_districts(province, name) as (
  values
    -- SAN JOSE
    ('San José', 'San José'), ('San José', 'Carmen'), ('San José', 'Merced'),
    ('San José', 'Hospital'), ('San José', 'Catedral'), ('San José', 'Zapote'),
    ('San José', 'San Francisco de Dos Ríos'), ('San José', 'Uruca'),
    ('San José', 'Mata Redonda'), ('San José', 'Pavas'), ('San José', 'Hatillo'),
    ('San José', 'San Sebastián'), ('San José', 'Escazú'), ('San José', 'San Antonio de Escazú'),
    ('San José', 'San Rafael de Escazú'), ('San José', 'Desamparados'),
    ('San José', 'San Miguel de Desamparados'), ('San José', 'San Juan de Dios'),
    ('San José', 'San Rafael Arriba'), ('San José', 'San Antonio de Desamparados'),
    ('San José', 'Frailes'), ('San José', 'Patarrá'), ('San José', 'San Cristóbal'),
    ('San José', 'Rosario'), ('San José', 'Damas'), ('San José', 'San Rafael Abajo'),
    ('San José', 'Gravilias'), ('San José', 'Los Guido'), ('San José', 'Puriscal'),
    ('San José', 'Santiago de Puriscal'), ('San José', 'Mercedes Sur'),
    ('San José', 'Barbacoas'), ('San José', 'Grifo Alto'), ('San José', 'San Rafael de Puriscal'),
    ('San José', 'Candelaria'), ('San José', 'Desamparaditos'), ('San José', 'Chires'),
    ('San José', 'Tarrazú'), ('San José', 'San Marcos'), ('San José', 'San Lorenzo'),
    ('San José', 'San Carlos de Tarrazú'), ('San José', 'Aserrí'), ('San José', 'Tarbaca'),
    ('San José', 'Vuelta de Jorco'), ('San José', 'San Gabriel'), ('San José', 'Legua'),
    ('San José', 'Monterrey'), ('San José', 'Salitrillos'), ('San José', 'Mora'),
    ('San José', 'Colón'), ('San José', 'Guayabo'), ('San José', 'Tabarcia'),
    ('San José', 'Piedras Negras'), ('San José', 'Picagres'), ('San José', 'Jaris'),
    ('San José', 'Quitirrisí'), ('San José', 'Goicoechea'), ('San José', 'Guadalupe'),
    ('San José', 'San Francisco de Goicoechea'), ('San José', 'Calle Blancos'),
    ('San José', 'Mata de Plátano'), ('San José', 'Ipís'), ('San José', 'Rancho Redondo'),
    ('San José', 'Purral'), ('San José', 'Santa Ana'), ('San José', 'Salitral'),
    ('San José', 'Pozos'), ('San José', 'Uruca de Santa Ana'), ('San José', 'Piedades'),
    ('San José', 'Brasil'), ('San José', 'Alajuelita'), ('San José', 'San Josecito'),
    ('San José', 'Concepción de Alajuelita'), ('San José', 'San Felipe'),
    ('San José', 'Vázquez de Coronado'), ('San José', 'San Isidro de Coronado'),
    ('San José', 'San Rafael de Coronado'), ('San José', 'Dulce Nombre de Jesús'),
    ('San José', 'Patalillo'), ('San José', 'Cascajal'), ('San José', 'Acosta'),
    ('San José', 'San Ignacio'), ('San José', 'Guaitil'), ('San José', 'Palmichal'),
    ('San José', 'Cangrejal'), ('San José', 'Sabanillas'), ('San José', 'Tibás'),
    ('San José', 'San Juan de Tibás'), ('San José', 'Cinco Esquinas'),
    ('San José', 'Anselmo Llorente'), ('San José', 'León XIII'), ('San José', 'Colima'),
    ('San José', 'Moravia'), ('San José', 'San Vicente'), ('San José', 'San Jerónimo'),
    ('San José', 'La Trinidad'), ('San José', 'Montes de Oca'), ('San José', 'San Pedro'),
    ('San José', 'Sabanilla'), ('San José', 'Mercedes de Montes de Oca'),
    ('San José', 'Turrubares'), ('San José', 'San Pablo de Turrubares'),
    ('San José', 'San Pedro de Turrubares'), ('San José', 'San Juan de Mata'),
    ('San José', 'San Luis'), ('San José', 'Carara'), ('San José', 'Dota'),
    ('San José', 'Santa María'), ('San José', 'Jardín'), ('San José', 'Copey'),
    ('San José', 'Curridabat'), ('San José', 'Granadilla'), ('San José', 'Sánchez'),
    ('San José', 'Tirrases'), ('San José', 'Pérez Zeledón'),
    ('San José', 'San Isidro de El General'), ('San José', 'El General'),
    ('San José', 'Daniel Flores'), ('San José', 'Rivas'), ('San José', 'Platanares'),
    ('San José', 'Pejibaye'), ('San José', 'Cajón'), ('San José', 'Barú'),
    ('San José', 'Río Nuevo'), ('San José', 'Páramo'), ('San José', 'La Amistad'),
    ('San José', 'León Cortés Castro'), ('San José', 'San Pablo de León Cortés'),
    ('San José', 'San Andrés'), ('San José', 'Llano Bonito'),

    -- ALAJUELA
    ('Alajuela', 'Alajuela'), ('Alajuela', 'San José de Alajuela'), ('Alajuela', 'Carrizal'),
    ('Alajuela', 'San Antonio de Alajuela'), ('Alajuela', 'Guácima'),
    ('Alajuela', 'San Isidro de Alajuela'), ('Alajuela', 'Sabanilla de Alajuela'),
    ('Alajuela', 'San Rafael de Alajuela'), ('Alajuela', 'Río Segundo'),
    ('Alajuela', 'Desamparados de Alajuela'), ('Alajuela', 'Turrúcares'),
    ('Alajuela', 'Tambor'), ('Alajuela', 'Garita'), ('Alajuela', 'Sarapiquí de Alajuela'),
    ('Alajuela', 'San Ramón'), ('Alajuela', 'Santiago de San Ramón'),
    ('Alajuela', 'San Juan de San Ramón'), ('Alajuela', 'Piedades Norte'),
    ('Alajuela', 'Piedades Sur'), ('Alajuela', 'San Rafael de San Ramón'),
    ('Alajuela', 'Alfaro'), ('Alajuela', 'Volio'), ('Alajuela', 'Zapotal'),
    ('Alajuela', 'Peñas Blancas'), ('Alajuela', 'San Lorenzo'), ('Alajuela', 'Grecia'),
    ('Alajuela', 'San Isidro de Grecia'), ('Alajuela', 'San Roque'),
    ('Alajuela', 'Tacares'), ('Alajuela', 'Puente de Piedra'), ('Alajuela', 'Bolívar'),
    ('Alajuela', 'San Mateo'), ('Alajuela', 'Desmonte'), ('Alajuela', 'Jesús María'),
    ('Alajuela', 'Labrador'), ('Alajuela', 'Atenas'), ('Alajuela', 'Jesús de Atenas'),
    ('Alajuela', 'Mercedes de Atenas'), ('Alajuela', 'Santa Eulalia'),
    ('Alajuela', 'Escobal'), ('Alajuela', 'Naranjo'), ('Alajuela', 'San Miguel de Naranjo'),
    ('Alajuela', 'Cirrí Sur'), ('Alajuela', 'San Jerónimo de Naranjo'),
    ('Alajuela', 'El Rosario'), ('Alajuela', 'Palmitos'), ('Alajuela', 'Palmares'),
    ('Alajuela', 'Zaragoza'), ('Alajuela', 'Buenos Aires de Palmares'),
    ('Alajuela', 'Candelaria de Palmares'), ('Alajuela', 'Esquipulas'),
    ('Alajuela', 'La Granja'), ('Alajuela', 'Poás'), ('Alajuela', 'San Pedro de Poás'),
    ('Alajuela', 'Carrillos'), ('Alajuela', 'Sabana Redonda'), ('Alajuela', 'Orotina'),
    ('Alajuela', 'El Mastate'), ('Alajuela', 'Hacienda Vieja'), ('Alajuela', 'Coyolar'),
    ('Alajuela', 'La Ceiba'), ('Alajuela', 'San Carlos'), ('Alajuela', 'Ciudad Quesada'),
    ('Alajuela', 'Florencia'), ('Alajuela', 'Buenavista'), ('Alajuela', 'Aguas Zarcas'),
    ('Alajuela', 'Venecia'), ('Alajuela', 'Pital'), ('Alajuela', 'La Fortuna'),
    ('Alajuela', 'La Tigra'), ('Alajuela', 'La Palmera'), ('Alajuela', 'Venado'),
    ('Alajuela', 'Cutris'), ('Alajuela', 'Monterrey de San Carlos'), ('Alajuela', 'Poco Sol'),
    ('Alajuela', 'Zarcero'), ('Alajuela', 'Laguna'), ('Alajuela', 'Tapesco'),
    ('Alajuela', 'Guadalupe de Zarcero'), ('Alajuela', 'Palmira'),
    ('Alajuela', 'Zapote de Zarcero'), ('Alajuela', 'Brisas'), ('Alajuela', 'Sarchí'),
    ('Alajuela', 'Sarchí Norte'), ('Alajuela', 'Sarchí Sur'), ('Alajuela', 'Toro Amarillo'),
    ('Alajuela', 'Rodríguez'), ('Alajuela', 'Upala'), ('Alajuela', 'Aguas Claras'),
    ('Alajuela', 'Bijagua'), ('Alajuela', 'Delicias'), ('Alajuela', 'Dos Ríos'),
    ('Alajuela', 'Yolillal'), ('Alajuela', 'Canalete'), ('Alajuela', 'Los Chiles'),
    ('Alajuela', 'Caño Negro'), ('Alajuela', 'El Amparo'), ('Alajuela', 'San Jorge'),
    ('Alajuela', 'Guatuso'), ('Alajuela', 'San Rafael de Guatuso'), ('Alajuela', 'Cote'),
    ('Alajuela', 'Katira'), ('Alajuela', 'Río Cuarto'), ('Alajuela', 'Santa Rita'),
    ('Alajuela', 'Santa Isabel'),

    -- CARTAGO
    ('Cartago', 'Cartago'), ('Cartago', 'Oriental'), ('Cartago', 'Occidental'),
    ('Cartago', 'Carmen de Cartago'), ('Cartago', 'San Nicolás'),
    ('Cartago', 'San Francisco de Cartago'), ('Cartago', 'Guadalupe de Cartago'),
    ('Cartago', 'Corralillo'), ('Cartago', 'Tierra Blanca'), ('Cartago', 'Dulce Nombre'),
    ('Cartago', 'Llano Grande'), ('Cartago', 'Quebradilla'), ('Cartago', 'Paraíso'),
    ('Cartago', 'Santiago de Paraíso'), ('Cartago', 'Orosi'), ('Cartago', 'Cachí'),
    ('Cartago', 'Llanos de Santa Lucía'), ('Cartago', 'Birrisito'),
    ('Cartago', 'La Unión'), ('Cartago', 'Tres Ríos'), ('Cartago', 'San Diego'),
    ('Cartago', 'San Juan de La Unión'), ('Cartago', 'San Rafael de La Unión'),
    ('Cartago', 'Concepción de La Unión'), ('Cartago', 'Río Azul'),
    ('Cartago', 'Jiménez'), ('Cartago', 'Juan Viñas'), ('Cartago', 'Tucurrique'),
    ('Cartago', 'Pejibaye de Jiménez'), ('Cartago', 'La Victoria'),
    ('Cartago', 'Turrialba'), ('Cartago', 'La Suiza'), ('Cartago', 'Peralta'),
    ('Cartago', 'Santa Cruz de Turrialba'), ('Cartago', 'Santa Teresita'),
    ('Cartago', 'Pavones'), ('Cartago', 'Tuis'), ('Cartago', 'Tayutic'),
    ('Cartago', 'Santa Rosa de Turrialba'), ('Cartago', 'Tres Equis'),
    ('Cartago', 'La Isabel'), ('Cartago', 'Chirripó'), ('Cartago', 'Alvarado'),
    ('Cartago', 'Pacayas'), ('Cartago', 'Cervantes'), ('Cartago', 'Capellades'),
    ('Cartago', 'Oreamuno'), ('Cartago', 'San Rafael de Oreamuno'), ('Cartago', 'Cot'),
    ('Cartago', 'Potrero Cerrado'), ('Cartago', 'Cipreses'),
    ('Cartago', 'Santa Rosa de Oreamuno'), ('Cartago', 'El Guarco'),
    ('Cartago', 'El Tejar'), ('Cartago', 'San Isidro de El Guarco'),
    ('Cartago', 'Tobosi'), ('Cartago', 'Patio de Agua'),

    -- HEREDIA
    ('Heredia', 'Heredia'), ('Heredia', 'Mercedes de Heredia'),
    ('Heredia', 'San Francisco de Heredia'), ('Heredia', 'Ulloa'),
    ('Heredia', 'Varablanca'), ('Heredia', 'Barva'), ('Heredia', 'San Pedro de Barva'),
    ('Heredia', 'San Pablo de Barva'), ('Heredia', 'San Roque de Barva'),
    ('Heredia', 'Santa Lucía'), ('Heredia', 'San José de la Montaña'),
    ('Heredia', 'Santo Domingo'), ('Heredia', 'San Vicente de Santo Domingo'),
    ('Heredia', 'San Miguel de Santo Domingo'), ('Heredia', 'Paracito'),
    ('Heredia', 'Santo Tomás'), ('Heredia', 'Santa Rosa de Santo Domingo'),
    ('Heredia', 'Tures'), ('Heredia', 'Pará'), ('Heredia', 'Santa Bárbara'),
    ('Heredia', 'San Pedro de Santa Bárbara'), ('Heredia', 'San Juan de Santa Bárbara'),
    ('Heredia', 'Jesús de Santa Bárbara'), ('Heredia', 'Santo Domingo de Santa Bárbara'),
    ('Heredia', 'Purabá'), ('Heredia', 'San Rafael'), ('Heredia', 'San Rafael de Heredia'),
    ('Heredia', 'San Josecito de San Rafael'), ('Heredia', 'Santiago de San Rafael'),
    ('Heredia', 'Ángeles de San Rafael'), ('Heredia', 'Concepción de San Rafael'),
    ('Heredia', 'San Isidro'), ('Heredia', 'San Isidro de Heredia'),
    ('Heredia', 'San José de San Isidro'), ('Heredia', 'Belén'),
    ('Heredia', 'San Antonio de Belén'), ('Heredia', 'La Ribera'),
    ('Heredia', 'La Asunción'), ('Heredia', 'Flores'), ('Heredia', 'San Joaquín'),
    ('Heredia', 'Barrantes'), ('Heredia', 'Llorente'), ('Heredia', 'San Pablo'),
    ('Heredia', 'San Pablo de Heredia'), ('Heredia', 'Rincón de Sabanilla'),
    ('Heredia', 'Sarapiquí'), ('Heredia', 'Puerto Viejo de Sarapiquí'),
    ('Heredia', 'La Virgen'), ('Heredia', 'Horquetas'),
    ('Heredia', 'Llanuras del Gaspar'), ('Heredia', 'Cureña'),

    -- GUANACASTE
    ('Guanacaste', 'Liberia'), ('Guanacaste', 'Cañas Dulces'), ('Guanacaste', 'Mayorga'),
    ('Guanacaste', 'Nacascolo'), ('Guanacaste', 'Curubandé'), ('Guanacaste', 'Nicoya'),
    ('Guanacaste', 'Mansión'), ('Guanacaste', 'San Antonio de Nicoya'),
    ('Guanacaste', 'Quebrada Honda'), ('Guanacaste', 'Sámara'), ('Guanacaste', 'Nambí'),
    ('Guanacaste', 'Belén de Nosarita'), ('Guanacaste', 'Nosara'),
    ('Guanacaste', 'Santa Cruz'), ('Guanacaste', 'Bolsón'),
    ('Guanacaste', 'Veintisiete de Abril'), ('Guanacaste', 'Tempate'),
    ('Guanacaste', 'Cartagena'), ('Guanacaste', 'Cuajiniquil'), ('Guanacaste', 'Diriá'),
    ('Guanacaste', 'Cabo Velas'), ('Guanacaste', 'Tamarindo'), ('Guanacaste', 'Bagaces'),
    ('Guanacaste', 'La Fortuna de Bagaces'), ('Guanacaste', 'Mogote'),
    ('Guanacaste', 'Río Naranjo'), ('Guanacaste', 'Carrillo'), ('Guanacaste', 'Filadelfia'),
    ('Guanacaste', 'Palmira de Carrillo'), ('Guanacaste', 'Sardinal'),
    ('Guanacaste', 'Belén de Carrillo'), ('Guanacaste', 'Cañas'),
    ('Guanacaste', 'Palmira de Cañas'), ('Guanacaste', 'San Miguel de Cañas'),
    ('Guanacaste', 'Bebedero'), ('Guanacaste', 'Porozó'), ('Guanacaste', 'Abangares'),
    ('Guanacaste', 'Las Juntas'), ('Guanacaste', 'Sierra'),
    ('Guanacaste', 'San Juan de Abangares'), ('Guanacaste', 'Colorado'),
    ('Guanacaste', 'Tilarán'), ('Guanacaste', 'Quebrada Grande'),
    ('Guanacaste', 'Tronadora'), ('Guanacaste', 'Santa Rosa de Tilarán'),
    ('Guanacaste', 'Líbano'), ('Guanacaste', 'Tierras Morenas'),
    ('Guanacaste', 'Arenal'), ('Guanacaste', 'Cabeceras'), ('Guanacaste', 'Nandayure'),
    ('Guanacaste', 'Carmona'), ('Guanacaste', 'Santa Rita de Nandayure'),
    ('Guanacaste', 'Zapotal de Nandayure'), ('Guanacaste', 'San Pablo de Nandayure'),
    ('Guanacaste', 'Porvenir'), ('Guanacaste', 'Bejuco'), ('Guanacaste', 'La Cruz'),
    ('Guanacaste', 'Santa Cecilia'), ('Guanacaste', 'La Garita de La Cruz'),
    ('Guanacaste', 'Santa Elena'), ('Guanacaste', 'Hojancha'),
    ('Guanacaste', 'Monte Romo'), ('Guanacaste', 'Puerto Carrillo'),
    ('Guanacaste', 'Huacas'), ('Guanacaste', 'Matambú'),

    -- PUNTARENAS
    ('Puntarenas', 'Puntarenas'), ('Puntarenas', 'Pitahaya'), ('Puntarenas', 'Chomes'),
    ('Puntarenas', 'Lepanto'), ('Puntarenas', 'Paquera'), ('Puntarenas', 'Manzanillo'),
    ('Puntarenas', 'Guacimal'), ('Puntarenas', 'Barranca'),
    ('Puntarenas', 'Cóbano'), ('Puntarenas', 'Chacarita'), ('Puntarenas', 'Chira'),
    ('Puntarenas', 'Acapulco'), ('Puntarenas', 'El Roble'), ('Puntarenas', 'Arancibia'),
    ('Puntarenas', 'Esparza'), ('Puntarenas', 'Espíritu Santo'),
    ('Puntarenas', 'San Juan Grande'), ('Puntarenas', 'Macacona'),
    ('Puntarenas', 'San Rafael de Esparza'), ('Puntarenas', 'San Jerónimo de Esparza'),
    ('Puntarenas', 'Caldera'), ('Puntarenas', 'Buenos Aires'),
    ('Puntarenas', 'Volcán'), ('Puntarenas', 'Potrero Grande'),
    ('Puntarenas', 'Boruca'), ('Puntarenas', 'Pilas'), ('Puntarenas', 'Colinas'),
    ('Puntarenas', 'Chánguena'), ('Puntarenas', 'Biolley'), ('Puntarenas', 'Brunka'),
    ('Puntarenas', 'Montes de Oro'), ('Puntarenas', 'Miramar'),
    ('Puntarenas', 'La Unión de Montes de Oro'),
    ('Puntarenas', 'San Isidro de Montes de Oro'), ('Puntarenas', 'Osa'),
    ('Puntarenas', 'Puerto Cortés'), ('Puntarenas', 'Palmar'), ('Puntarenas', 'Sierpe'),
    ('Puntarenas', 'Bahía Ballena'), ('Puntarenas', 'Piedras Blancas'),
    ('Puntarenas', 'Bahía Drake'), ('Puntarenas', 'Quepos'),
    ('Puntarenas', 'Savegre'), ('Puntarenas', 'Naranjito'), ('Puntarenas', 'Golfito'),
    ('Puntarenas', 'Guaycará'), ('Puntarenas', 'Pavones'), ('Puntarenas', 'Coto Brus'),
    ('Puntarenas', 'San Vito'), ('Puntarenas', 'Sabalito'), ('Puntarenas', 'Aguabuena'),
    ('Puntarenas', 'Limoncito'), ('Puntarenas', 'Pittier'),
    ('Puntarenas', 'Gutiérrez Braun'), ('Puntarenas', 'Parrita'),
    ('Puntarenas', 'Corredores'), ('Puntarenas', 'Corredor'),
    ('Puntarenas', 'La Cuesta'), ('Puntarenas', 'Canoas'), ('Puntarenas', 'Laurel'),
    ('Puntarenas', 'Garabito'), ('Puntarenas', 'Jacó'), ('Puntarenas', 'Tárcoles'),
    ('Puntarenas', 'Lagunillas'), ('Puntarenas', 'Monteverde'),
    ('Puntarenas', 'Puerto Jiménez'),

    -- LIMON
    ('Limón', 'Limón'), ('Limón', 'Valle La Estrella'), ('Limón', 'Río Blanco'),
    ('Limón', 'Matama'), ('Limón', 'Pococí'), ('Limón', 'Guápiles'),
    ('Limón', 'Jiménez de Pococí'), ('Limón', 'Rita'), ('Limón', 'Roxana'),
    ('Limón', 'Cariari'), ('Limón', 'Colorado de Pococí'), ('Limón', 'La Colonia'),
    ('Limón', 'Siquirres'), ('Limón', 'Pacuarito'), ('Limón', 'Florida'),
    ('Limón', 'Germania'), ('Limón', 'El Cairo'), ('Limón', 'Alegría'),
    ('Limón', 'Reventazón'), ('Limón', 'Talamanca'), ('Limón', 'Bribri'),
    ('Limón', 'Sixaola'), ('Limón', 'Cahuita'), ('Limón', 'Telire'),
    ('Limón', 'Matina'), ('Limón', 'Batán'), ('Limón', 'Carrandi'),
    ('Limón', 'Guácimo'), ('Limón', 'Mercedes de Guácimo'), ('Limón', 'Pocora'),
    ('Limón', 'Río Jiménez'), ('Limón', 'Duacarí')
)
insert into public.cities (country_code, administrative_area_id, province_name, name, is_active)
select
  'CR',
  p.id,
  d.province,
  d.name,
  true
from raw_districts d
join prov_ids p on p.name = d.province
on conflict (country_code, lower(btrim(province_name)), lower(btrim(name))) do nothing;

-- ============================================================
-- 4. Extender tabla customers con country_code y city
-- ============================================================

alter table public.customers
  add column if not exists country_code text not null default 'CR' references public.countries(code) on update cascade,
  add column if not exists city text;

-- ============================================================
-- 5. Actualizar create_customer y update_customer
-- ============================================================

drop function if exists
  public.create_customer(text, text, text, text, text, text, numeric, text, text, uuid, text, integer, text, boolean, uuid, text, text, text, text);
drop function if exists
  public.update_customer(uuid, text, text, text, text, text, text, numeric, text, text, uuid, text, integer, text, boolean, uuid, text, text, text, text);
drop function if exists
  public.create_customer(text, text, text, text, text, text, numeric, text, text, text, text, uuid, text, integer, text, boolean, uuid, text, text, text, text);
drop function if exists
  public.update_customer(uuid, text, text, text, text, text, text, numeric, text, text, text, text, uuid, text, integer, text, boolean, uuid, text, text, text, text);

create or replace function public.create_customer(
  p_name text,
  p_display_name text,
  p_phone text,
  p_email text,
  p_address text,
  p_tax_id text,
  p_credit_limit numeric,
  p_country_code text,
  p_province text,
  p_city text,
  p_gira text,
  p_preferred_carrier_id uuid,
  p_customer_type text,
  p_credit_days integer,
  p_document_preference text,
  p_requires_e_invoice boolean,
  p_identification_type_id uuid,
  p_economic_activity text,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.customers
language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
  v_country text;
  v_province text;
  v_city text;
  v_area_id uuid;
  v_row public.customers%rowtype;
begin
  if btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  if coalesce(p_customer_type, 'CASH') = 'CREDIT'
     and (p_credit_days is null or p_credit_days <= 0) then
    raise exception using errcode = 'P0001', message = 'CREDIT_DAYS_REQUIRED';
  end if;
  if p_preferred_carrier_id is not null
     and not exists (
       select 1 from public.carriers
        where id = p_preferred_carrier_id and is_active
     ) then
    raise exception using errcode = 'P0001', message = 'CARRIER_INACTIVE';
  end if;
  if p_identification_type_id is not null
     and not exists (
       select 1 from public.identification_types
        where id = p_identification_type_id and is_active
     ) then
    raise exception using errcode = 'P0001', message = 'IDENTIFICATION_TYPE_INACTIVE';
  end if;

  v_country := coalesce(nullif(btrim(p_country_code), ''), 'CR');
  v_province := nullif(btrim(p_province), '');
  v_city := nullif(btrim(p_city), '');

  if not exists (select 1 from public.countries where code = v_country and is_active) then
    raise exception using errcode = 'P0001', message = 'COUNTRY_INACTIVE_OR_INVALID';
  end if;

  if coalesce(p_requires_e_invoice, false) then
    if btrim(coalesce(p_tax_id, '')) = '' then
      raise exception using errcode = 'P0001', message = 'E_INVOICE_TAX_ID_REQUIRED';
    end if;
    if p_identification_type_id is null then
      raise exception using errcode = 'P0001', message = 'E_INVOICE_IDENTIFICATION_TYPE_REQUIRED';
    end if;
    if btrim(coalesce(p_email, '')) = '' then
      raise exception using errcode = 'P0001', message = 'E_INVOICE_EMAIL_REQUIRED';
    end if;
    if btrim(coalesce(p_address, '')) = '' then
      raise exception using errcode = 'P0001', message = 'E_INVOICE_ADDRESS_REQUIRED';
    end if;
    if btrim(coalesce(p_economic_activity, '')) = '' then
      raise exception using errcode = 'P0001', message = 'E_INVOICE_ECONOMIC_ACTIVITY_REQUIRED';
    end if;
  end if;

  -- Autoaprendizaje de ciudades/distritos (Decisión 29)
  if v_city is not null and v_province is not null then
    select id into v_area_id
      from public.administrative_areas
     where country_code = v_country
       and lower(btrim(name)) = lower(btrim(v_province))
     limit 1;

    insert into public.cities (
      country_code, administrative_area_id, province_name, name, is_active
    ) values (
      v_country, v_area_id, v_province, v_city, true
    ) on conflict (country_code, lower(btrim(province_name)), lower(btrim(name)))
      do nothing;
  end if;

  insert into public.customers (
    name, display_name, phone, email, address, tax_id, credit_limit,
    country_code, province, city, gira, preferred_carrier_id, customer_type, credit_days,
    document_preference, requires_e_invoice, identification_type_id,
    economic_activity, created_by, created_device_name,
    created_device_identifier
  )
  values (
    btrim(p_name), nullif(btrim(p_display_name), ''), p_phone, p_email,
    p_address, p_tax_id, coalesce(p_credit_limit, 0),
    v_country, v_province, v_city, nullif(btrim(p_gira), ''),
    p_preferred_carrier_id, coalesce(p_customer_type, 'CASH'),
    case when coalesce(p_customer_type, 'CASH') = 'CREDIT' then p_credit_days else null end,
    coalesce(p_document_preference, 'E_INVOICE'),
    coalesce(p_requires_e_invoice, false),
    p_identification_type_id,
    nullif(btrim(p_economic_activity), ''),
    p_actor_name, p_device_name, p_device_identifier
  )
  returning id into v_id;

  select * into v_row from public.customers where id = v_id;
  return v_row;
end;
$$;

revoke all on function public.create_customer(text, text, text, text, text, text, numeric, text, text, text, text, uuid, text, integer, text, boolean, uuid, text, text, text, text) from public;
grant execute on function public.create_customer(text, text, text, text, text, text, numeric, text, text, text, text, uuid, text, integer, text, boolean, uuid, text, text, text, text) to anon, authenticated;

create or replace function public.update_customer(
  p_customer_id uuid,
  p_name text,
  p_display_name text,
  p_phone text,
  p_email text,
  p_address text,
  p_tax_id text,
  p_credit_limit numeric,
  p_country_code text,
  p_province text,
  p_city text,
  p_gira text,
  p_preferred_carrier_id uuid,
  p_customer_type text,
  p_credit_days integer,
  p_document_preference text,
  p_requires_e_invoice boolean,
  p_identification_type_id uuid,
  p_economic_activity text,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.customers
language plpgsql security definer set search_path = '' as $$
declare
  v_country text;
  v_province text;
  v_city text;
  v_area_id uuid;
  v public.customers%rowtype;
begin
  if btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  if coalesce(p_customer_type, 'CASH') = 'CREDIT'
     and (p_credit_days is null or p_credit_days <= 0) then
    raise exception using errcode = 'P0001', message = 'CREDIT_DAYS_REQUIRED';
  end if;
  if p_preferred_carrier_id is not null
     and not exists (
       select 1 from public.carriers
        where id = p_preferred_carrier_id and is_active
     ) then
    raise exception using errcode = 'P0001', message = 'CARRIER_INACTIVE';
  end if;
  if p_identification_type_id is not null
     and not exists (
       select 1 from public.identification_types
        where id = p_identification_type_id and is_active
     ) then
    raise exception using errcode = 'P0001', message = 'IDENTIFICATION_TYPE_INACTIVE';
  end if;

  v_country := coalesce(nullif(btrim(p_country_code), ''), 'CR');
  v_province := nullif(btrim(p_province), '');
  v_city := nullif(btrim(p_city), '');

  if not exists (select 1 from public.countries where code = v_country and is_active) then
    raise exception using errcode = 'P0001', message = 'COUNTRY_INACTIVE_OR_INVALID';
  end if;

  if coalesce(p_requires_e_invoice, false) then
    if btrim(coalesce(p_tax_id, '')) = '' then
      raise exception using errcode = 'P0001', message = 'E_INVOICE_TAX_ID_REQUIRED';
    end if;
    if p_identification_type_id is null then
      raise exception using errcode = 'P0001', message = 'E_INVOICE_IDENTIFICATION_TYPE_REQUIRED';
    end if;
    if btrim(coalesce(p_email, '')) = '' then
      raise exception using errcode = 'P0001', message = 'E_INVOICE_EMAIL_REQUIRED';
    end if;
    if btrim(coalesce(p_address, '')) = '' then
      raise exception using errcode = 'P0001', message = 'E_INVOICE_ADDRESS_REQUIRED';
    end if;
    if btrim(coalesce(p_economic_activity, '')) = '' then
      raise exception using errcode = 'P0001', message = 'E_INVOICE_ECONOMIC_ACTIVITY_REQUIRED';
    end if;
  end if;

  -- Autoaprendizaje de ciudades/distritos (Decisión 29)
  if v_city is not null and v_province is not null then
    select id into v_area_id
      from public.administrative_areas
     where country_code = v_country
       and lower(btrim(name)) = lower(btrim(v_province))
     limit 1;

    insert into public.cities (
      country_code, administrative_area_id, province_name, name, is_active
    ) values (
      v_country, v_area_id, v_province, v_city, true
    ) on conflict (country_code, lower(btrim(province_name)), lower(btrim(name)))
      do nothing;
  end if;

  update public.customers
     set name = btrim(p_name),
         display_name = nullif(btrim(p_display_name), ''),
         phone = p_phone,
         email = p_email,
         address = p_address,
         tax_id = p_tax_id,
         credit_limit = coalesce(p_credit_limit, 0),
         country_code = v_country,
         province = v_province,
         city = v_city,
         gira = nullif(btrim(p_gira), ''),
         preferred_carrier_id = p_preferred_carrier_id,
         customer_type = coalesce(p_customer_type, 'CASH'),
         credit_days = case when coalesce(p_customer_type, 'CASH') = 'CREDIT' then p_credit_days else null end,
         document_preference = coalesce(p_document_preference, 'E_INVOICE'),
         requires_e_invoice = coalesce(p_requires_e_invoice, false),
         identification_type_id = p_identification_type_id,
         economic_activity = nullif(btrim(p_economic_activity), ''),
         updated_by = p_actor_name,
         updated_device_name = p_device_name,
         updated_device_identifier = p_device_identifier,
         updated_at = now()
   where id = p_customer_id
  returning * into v;

  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;

  return v;
end;
$$;

revoke all on function public.update_customer(uuid, text, text, text, text, text, text, numeric, text, text, text, text, uuid, text, integer, text, boolean, uuid, text, text, text, text) from public;
grant execute on function public.update_customer(uuid, text, text, text, text, text, text, numeric, text, text, text, text, uuid, text, integer, text, boolean, uuid, text, text, text, text) to anon, authenticated;

-- Wrapper de compatibilidad hacia atras (19 parametros) para create_customer
create or replace function public.create_customer(
  p_name text,
  p_display_name text,
  p_phone text,
  p_email text,
  p_address text,
  p_tax_id text,
  p_credit_limit numeric,
  p_province text,
  p_gira text,
  p_preferred_carrier_id uuid,
  p_customer_type text,
  p_credit_days integer,
  p_document_preference text,
  p_requires_e_invoice boolean,
  p_identification_type_id uuid,
  p_economic_activity text,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.customers
language sql security definer set search_path = '' as $$
  select public.create_customer(
    p_name := p_name,
    p_display_name := p_display_name,
    p_phone := p_phone,
    p_email := p_email,
    p_address := p_address,
    p_tax_id := p_tax_id,
    p_credit_limit := p_credit_limit,
    p_country_code := 'CR',
    p_province := p_province,
    p_city := null,
    p_gira := p_gira,
    p_preferred_carrier_id := p_preferred_carrier_id,
    p_customer_type := p_customer_type,
    p_credit_days := p_credit_days,
    p_document_preference := p_document_preference,
    p_requires_e_invoice := p_requires_e_invoice,
    p_identification_type_id := p_identification_type_id,
    p_economic_activity := p_economic_activity,
    p_actor_name := p_actor_name,
    p_device_name := p_device_name,
    p_device_identifier := p_device_identifier
  );
$$;

revoke all on function public.create_customer(text, text, text, text, text, text, numeric, text, text, uuid, text, integer, text, boolean, uuid, text, text, text, text) from public;
grant execute on function public.create_customer(text, text, text, text, text, text, numeric, text, text, uuid, text, integer, text, boolean, uuid, text, text, text, text) to anon, authenticated;

-- Wrapper de compatibilidad hacia atras (19 parametros) para update_customer
create or replace function public.update_customer(
  p_customer_id uuid,
  p_name text,
  p_display_name text,
  p_phone text,
  p_email text,
  p_address text,
  p_tax_id text,
  p_credit_limit numeric,
  p_province text,
  p_gira text,
  p_preferred_carrier_id uuid,
  p_customer_type text,
  p_credit_days integer,
  p_document_preference text,
  p_requires_e_invoice boolean,
  p_identification_type_id uuid,
  p_economic_activity text,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.customers
language sql security definer set search_path = '' as $$
  select public.update_customer(
    p_customer_id := p_customer_id,
    p_name := p_name,
    p_display_name := p_display_name,
    p_phone := p_phone,
    p_email := p_email,
    p_address := p_address,
    p_tax_id := p_tax_id,
    p_credit_limit := p_credit_limit,
    p_country_code := 'CR',
    p_province := p_province,
    p_city := null,
    p_gira := p_gira,
    p_preferred_carrier_id := p_preferred_carrier_id,
    p_customer_type := p_customer_type,
    p_credit_days := p_credit_days,
    p_document_preference := p_document_preference,
    p_requires_e_invoice := p_requires_e_invoice,
    p_identification_type_id := p_identification_type_id,
    p_economic_activity := p_economic_activity,
    p_actor_name := p_actor_name,
    p_device_name := p_device_name,
    p_device_identifier := p_device_identifier
  );
$$;

revoke all on function public.update_customer(uuid, text, text, text, text, text, text, numeric, text, text, uuid, text, integer, text, boolean, uuid, text, text, text, text) from public;
grant execute on function public.update_customer(uuid, text, text, text, text, text, text, numeric, text, text, uuid, text, integer, text, boolean, uuid, text, text, text, text) to anon, authenticated;
