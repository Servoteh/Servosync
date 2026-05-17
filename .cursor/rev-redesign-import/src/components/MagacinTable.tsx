import React from 'react';
import { Eye, Pencil, MapPin, Wrench, Scissors } from 'lucide-react';
type Row = {
  katBr: string;
  barkod?: string;
  naziv: string;
  grupa: 'rucni' | 'rezni';
  lokacija?: string;
  kolicina: number;
  minKolicina: number;
  jm: string;
  azurirano: string;
};
const ROWS: Row[] = [
{
  katBr: 'AL-001',
  barkod: '8600123000017',
  naziv: 'Glodalo D12 HSS',
  grupa: 'rezni',
  lokacija: 'WH-A-03-12',
  kolicina: 24,
  minKolicina: 10,
  jm: 'kom',
  azurirano: '07.05.2026.'
},
{
  katBr: 'AL-014',
  barkod: '8600123000148',
  naziv: 'Burgija HSS Ø8 mm',
  grupa: 'rezni',
  lokacija: 'WH-A-04-02',
  kolicina: 5,
  minKolicina: 12,
  jm: 'kom',
  azurirano: '06.05.2026.'
},
{
  katBr: 'RA-211',
  naziv: 'Akumulatorska bušilica Bosch GSB 18V',
  grupa: 'rucni',
  kolicina: 1,
  minKolicina: 1,
  jm: 'kom',
  azurirano: '09.05.2026.'
},
{
  katBr: 'RA-058',
  naziv: 'Momentni ključ 1/2"',
  grupa: 'rucni',
  kolicina: 1,
  minKolicina: 2,
  jm: 'kom',
  azurirano: '02.05.2026.'
},
{
  katBr: 'AL-077',
  barkod: '8600123000772',
  naziv: 'Pločica za struženje TNMG 160404',
  grupa: 'rezni',
  lokacija: 'WH-B-01-09',
  kolicina: 0,
  minKolicina: 20,
  jm: 'kom',
  azurirano: '04.05.2026.'
},
{
  katBr: 'RA-102',
  naziv: 'Set imbus ključeva 1.5–10 mm',
  grupa: 'rucni',
  kolicina: 1,
  minKolicina: 1,
  jm: 'set',
  azurirano: '28.04.2026.'
},
{
  katBr: 'AL-033',
  barkod: '8600123000338',
  naziv: 'Glodalo D6 VHM 4-zub',
  grupa: 'rezni',
  lokacija: 'WH-A-03-08',
  kolicina: 18,
  minKolicina: 8,
  jm: 'kom',
  azurirano: '08.05.2026.'
},
{
  katBr: 'RA-019',
  naziv: 'Električna brusilica Makita GA9020',
  grupa: 'rucni',
  kolicina: 1,
  minKolicina: 1,
  jm: 'kom',
  azurirano: '01.05.2026.'
},
{
  katBr: 'AL-122',
  barkod: '8600123001225',
  naziv: 'Burgija za beton SDS-Plus Ø10 mm',
  grupa: 'rezni',
  lokacija: 'WH-B-02-04',
  kolicina: 32,
  minKolicina: 15,
  jm: 'kom',
  azurirano: '05.05.2026.'
},
{
  katBr: 'RA-066',
  naziv: 'Šubler digitalni 0–150 mm',
  grupa: 'rucni',
  kolicina: 1,
  minKolicina: 1,
  jm: 'kom',
  azurirano: '03.05.2026.'
}];

function StatusPill({ row }: {row: Row;}) {
  if (row.kolicina === 0) {
    return (
      <span className="inline-flex items-center gap-1.5 px-2 py-0.5 text-xs font-semibold rounded-md bg-red-50 text-red-700 border border-red-200">
        <span className="w-1.5 h-1.5 rounded-full bg-red-500" />
        Nema
      </span>);

  }
  if (row.kolicina < row.minKolicina) {
    return (
      <span className="inline-flex items-center gap-1.5 px-2 py-0.5 text-xs font-semibold rounded-md bg-amber-50 text-amber-700 border border-amber-200">
        <span className="w-1.5 h-1.5 rounded-full bg-amber-500" />
        Nisko stanje
      </span>);

  }
  return (
    <span className="inline-flex items-center gap-1.5 px-2 py-0.5 text-xs font-semibold rounded-md bg-green-50 text-green-700 border border-green-200">
      <span className="w-1.5 h-1.5 rounded-full bg-green-500" />
      Na stanju
    </span>);

}
function GrupaBadge({ grupa }: {grupa: 'rucni' | 'rezni';}) {
  if (grupa === 'rezni') {
    return (
      <span className="inline-flex items-center gap-1 px-2 py-0.5 text-xs font-medium rounded-md bg-purple-50 text-purple-700 border border-purple-100">
        <Scissors className="w-3 h-3" /> Rezni
      </span>);

  }
  return (
    <span className="inline-flex items-center gap-1 px-2 py-0.5 text-xs font-medium rounded-md bg-blue-50 text-blue-700 border border-blue-100">
      <Wrench className="w-3 h-3" /> Ručni
    </span>);

}
type MagacinTableProps = {
  search: string;
  group: 'sve' | 'rucni' | 'rezni';
  showZero: boolean;
};
export function MagacinTable({ search, group, showZero }: MagacinTableProps) {
  const filtered = ROWS.filter((r) => {
    if (group !== 'sve' && r.grupa !== group) return false;
    if (!showZero && r.kolicina === 0) return false;
    if (search.trim()) {
      const q = search.toLowerCase();
      if (
      !r.katBr.toLowerCase().includes(q) &&
      !r.naziv.toLowerCase().includes(q) &&
      !(r.barkod || '').toLowerCase().includes(q))

      return false;
    }
    return true;
  });
  return (
    <div className="bg-white border border-gray-200 rounded-lg shadow-sm overflow-hidden">
      <div className="flex items-center justify-between px-4 py-2.5 bg-gray-50 border-b border-gray-200">
        <div className="text-xs font-semibold tracking-wider text-gray-500 uppercase">
          {filtered.length} artikala prikazano
        </div>
        <div className="text-xs text-gray-500">
          Sortirano po:{' '}
          <span className="font-medium text-gray-700">Kataloški broj ↑</span>
        </div>
      </div>

      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="bg-gray-50 border-b border-gray-200 text-left text-[11px] font-semibold tracking-wider text-gray-500 uppercase">
              <th className="px-4 py-2.5 w-32">Kataloški broj</th>
              <th className="px-4 py-2.5">Naziv</th>
              <th className="px-4 py-2.5 w-28">Grupa</th>
              <th className="px-4 py-2.5 w-40">Lokacija</th>
              <th className="px-4 py-2.5 w-32 text-right">Količina</th>
              <th className="px-4 py-2.5 w-32">Status</th>
              <th className="px-4 py-2.5 w-32">Ažurirano</th>
              <th className="px-4 py-2.5 w-24 text-right">Akcije</th>
            </tr>
          </thead>
          <tbody>
            {filtered.length === 0 &&
            <tr>
                <td
                colSpan={8}
                className="px-4 py-12 text-center text-gray-500">
                
                  Nema artikala u magacinu prema filteru.
                </td>
              </tr>
            }
            {filtered.map((r, idx) => {
              const isLow = r.kolicina < r.minKolicina && r.kolicina > 0;
              const isZero = r.kolicina === 0;
              return (
                <tr
                  key={r.katBr}
                  className={`border-b border-gray-100 hover:bg-primary-light/30 transition-colors ${idx % 2 === 1 ? 'bg-gray-50/40' : ''}`}>
                  
                  <td className="px-4 py-3">
                    <div className="font-mono text-sm font-semibold text-gray-900">
                      {r.katBr}
                    </div>
                    {r.barkod &&
                    <div className="font-mono text-[11px] text-gray-400 mt-0.5">
                        {r.barkod}
                      </div>
                    }
                  </td>
                  <td className="px-4 py-3 text-gray-900">{r.naziv}</td>
                  <td className="px-4 py-3">
                    <GrupaBadge grupa={r.grupa} />
                  </td>
                  <td className="px-4 py-3">
                    {r.lokacija ?
                    <span className="inline-flex items-center gap-1 font-mono text-xs text-gray-700 bg-gray-100 px-2 py-0.5 rounded">
                        <MapPin className="w-3 h-3 text-gray-400" />
                        {r.lokacija}
                      </span> :

                    <span className="text-gray-300">—</span>
                    }
                  </td>
                  <td className="px-4 py-3 text-right">
                    <div className="flex items-baseline justify-end gap-1">
                      <span
                        className={`text-base font-bold ${isZero ? 'text-red-600' : isLow ? 'text-amber-600' : 'text-gray-900'}`}>
                        
                        {r.kolicina}
                      </span>
                      <span className="text-xs text-gray-400">{r.jm}</span>
                    </div>
                    <div className="text-[11px] text-gray-400 mt-0.5">
                      min. {r.minKolicina}
                    </div>
                  </td>
                  <td className="px-4 py-3">
                    <StatusPill row={r} />
                  </td>
                  <td className="px-4 py-3 text-gray-500 text-xs">
                    {r.azurirano}
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex items-center justify-end gap-1">
                      <button
                        title="Pregled"
                        className="p-1.5 text-gray-400 hover:text-primary hover:bg-primary-light rounded transition-colors">
                        
                        <Eye className="w-4 h-4" />
                      </button>
                      <button
                        title="Izmena"
                        className="p-1.5 text-gray-400 hover:text-gray-700 hover:bg-gray-100 rounded transition-colors">
                        
                        <Pencil className="w-4 h-4" />
                      </button>
                    </div>
                  </td>
                </tr>);

            })}
          </tbody>
        </table>
      </div>
    </div>);

}