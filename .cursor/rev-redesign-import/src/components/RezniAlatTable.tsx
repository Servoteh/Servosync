import React, { useState, Fragment } from 'react';
import { Eye, Pencil, Printer, ChevronRight } from 'lucide-react';
type Row = {
  oznaka: string;
  barkod?: string;
  naziv: string;
  klasa: 'Glodalo' | 'Burgija' | 'Pločica' | 'Urezivač' | 'Razvrtač';
  uMagacinu: number;
  naMasinama: {
    masina: string;
    kolicina: number;
  }[];
  minKolicina: number;
  status: 'aktivna' | 'povučena';
};
const ROWS: Row[] = [
{
  oznaka: 'RZN-000123',
  barkod: '8600200001234',
  naziv: 'Glodalo D12 HSS 4-zub',
  klasa: 'Glodalo',
  uMagacinu: 24,
  naMasinama: [
  {
    masina: 'CNC-01',
    kolicina: 2
  },
  {
    masina: 'CNC-03',
    kolicina: 1
  }],

  minKolicina: 10,
  status: 'aktivna'
},
{
  oznaka: 'RZN-000148',
  barkod: '8600200001487',
  naziv: 'Burgija HSS Ø8 mm DIN 338',
  klasa: 'Burgija',
  uMagacinu: 5,
  naMasinama: [
  {
    masina: 'CNC-02',
    kolicina: 4
  }],

  minKolicina: 12,
  status: 'aktivna'
},
{
  oznaka: 'RZN-000211',
  barkod: '8600200002118',
  naziv: 'Pločica TNMG 160404 P25',
  klasa: 'Pločica',
  uMagacinu: 0,
  naMasinama: [
  {
    masina: 'Strug-01',
    kolicina: 8
  }],

  minKolicina: 20,
  status: 'aktivna'
},
{
  oznaka: 'RZN-000077',
  barkod: '8600200000770',
  naziv: 'Urezivač M6 HSS-Co',
  klasa: 'Urezivač',
  uMagacinu: 14,
  naMasinama: [],
  minKolicina: 6,
  status: 'aktivna'
},
{
  oznaka: 'RZN-000302',
  barkod: '8600200003023',
  naziv: 'Glodalo D6 VHM 4-zub TiAlN',
  klasa: 'Glodalo',
  uMagacinu: 18,
  naMasinama: [
  {
    masina: 'CNC-01',
    kolicina: 3
  },
  {
    masina: 'CNC-02',
    kolicina: 2
  },
  {
    masina: 'CNC-03',
    kolicina: 2
  }],

  minKolicina: 8,
  status: 'aktivna'
},
{
  oznaka: 'RZN-000045',
  barkod: '8600200000459',
  naziv: 'Razvrtač Ø10 H7 HSS',
  klasa: 'Razvrtač',
  uMagacinu: 6,
  naMasinama: [
  {
    masina: 'CNC-03',
    kolicina: 1
  }],

  minKolicina: 4,
  status: 'aktivna'
},
{
  oznaka: 'RZN-000189',
  barkod: '8600200001890',
  naziv: 'Burgija za beton SDS-Plus Ø10 mm',
  klasa: 'Burgija',
  uMagacinu: 32,
  naMasinama: [],
  minKolicina: 15,
  status: 'aktivna'
},
{
  oznaka: 'RZN-000099',
  naziv: 'Glodalo D8 HSS - povučeno iz upotrebe',
  klasa: 'Glodalo',
  uMagacinu: 0,
  naMasinama: [],
  minKolicina: 0,
  status: 'povučena'
}];

const KLASA_COLORS: Record<Row['klasa'], string> = {
  Glodalo: 'bg-purple-50 text-purple-700 border-purple-100',
  Burgija: 'bg-blue-50 text-blue-700 border-blue-100',
  Pločica: 'bg-amber-50 text-amber-700 border-amber-100',
  Urezivač: 'bg-teal-50 text-teal-700 border-teal-100',
  Razvrtač: 'bg-pink-50 text-pink-700 border-pink-100'
};
function StatusPill({ status }: {status: Row['status'];}) {
  if (status === 'povučena') {
    return (
      <span className="inline-flex items-center gap-1.5 px-2 py-0.5 text-xs font-semibold rounded-md bg-gray-100 text-gray-600 border border-gray-200">
        <span className="w-1.5 h-1.5 rounded-full bg-gray-400" />
        Povučena
      </span>);

  }
  return (
    <span className="inline-flex items-center gap-1.5 px-2 py-0.5 text-xs font-semibold rounded-md bg-green-50 text-green-700 border border-green-200">
      <span className="w-1.5 h-1.5 rounded-full bg-green-500" />
      Aktivna
    </span>);

}
type RezniAlatTableProps = {
  search: string;
  klasa: string;
  masina: string;
  status: string;
  selected: string[];
  onSelectedChange: (next: string[]) => void;
};
export function RezniAlatTable({
  search,
  klasa,
  masina,
  status,
  selected,
  onSelectedChange
}: RezniAlatTableProps) {
  const [expanded, setExpanded] = useState<string | null>(null);
  const filtered = ROWS.filter((r) => {
    if (status === 'aktivne' && r.status !== 'aktivna') return false;
    if (status === 'povucene' && r.status !== 'povučena') return false;
    if (klasa !== 'all' && r.klasa.toLowerCase() !== klasa) return false;
    if (masina !== 'all') {
      if (
      !r.naMasinama.some(
        (m) => m.masina.toLowerCase().replace(' ', '-') === masina
      ))

      return false;
    }
    if (search.trim()) {
      const q = search.toLowerCase();
      if (
      !r.oznaka.toLowerCase().includes(q) &&
      !r.naziv.toLowerCase().includes(q) &&
      !r.klasa.toLowerCase().includes(q) &&
      !(r.barkod || '').toLowerCase().includes(q))

      return false;
    }
    return true;
  });
  const toggleAll = () => {
    if (selected.length === filtered.length) {
      onSelectedChange([]);
    } else {
      onSelectedChange(filtered.map((r) => r.oznaka));
    }
  };
  const toggleOne = (oznaka: string) => {
    if (selected.includes(oznaka)) {
      onSelectedChange(selected.filter((s) => s !== oznaka));
    } else {
      onSelectedChange([...selected, oznaka]);
    }
  };
  return (
    <div className="bg-white border border-gray-200 rounded-lg shadow-sm overflow-hidden">
      <div className="flex items-center justify-between px-4 py-2.5 bg-gray-50 border-b border-gray-200">
        <div className="text-xs font-semibold tracking-wider text-gray-500 uppercase">
          {filtered.length} šifri prikazano
          {selected.length > 0 &&
          <span className="ml-2 normal-case font-normal text-primary">
              · {selected.length} odabrano
            </span>
          }
        </div>
        <div className="text-xs text-gray-500">
          Sortirano po:{' '}
          <span className="font-medium text-gray-700">Oznaka ↑</span>
        </div>
      </div>

      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="bg-gray-50 border-b border-gray-200 text-left text-[11px] font-semibold tracking-wider text-gray-500 uppercase">
              <th className="px-3 py-2.5 w-10">
                <input
                  type="checkbox"
                  checked={
                  selected.length > 0 && selected.length === filtered.length
                  }
                  onChange={toggleAll}
                  className="w-4 h-4 accent-primary" />
                
              </th>
              <th className="px-4 py-2.5 w-40">Oznaka</th>
              <th className="px-4 py-2.5">Naziv</th>
              <th className="px-4 py-2.5 w-28">Klasa</th>
              <th className="px-4 py-2.5 w-28 text-right">U magacinu</th>
              <th className="px-4 py-2.5 w-32 text-right">Na mašinama</th>
              <th className="px-4 py-2.5 w-24 text-right">Ukupno</th>
              <th className="px-4 py-2.5 w-28">Status</th>
              <th className="px-4 py-2.5 w-32 text-right">Akcije</th>
            </tr>
          </thead>
          <tbody>
            {filtered.length === 0 &&
            <tr>
                <td
                colSpan={9}
                className="px-4 py-12 text-center text-gray-500">
                
                  Nema šifri reznog alata koje odgovaraju filteru.
                </td>
              </tr>
            }
            {filtered.map((r, idx) => {
              const totalNaMas = r.naMasinama.reduce(
                (s, m) => s + m.kolicina,
                0
              );
              const ukupno = r.uMagacinu + totalNaMas;
              const isLow = ukupno < r.minKolicina && r.minKolicina > 0;
              const isExpanded = expanded === r.oznaka;
              const isSelected = selected.includes(r.oznaka);
              return (
                <Fragment key={r.oznaka}>
                  <tr
                    className={`border-b border-gray-100 hover:bg-primary-light/30 transition-colors ${idx % 2 === 1 ? 'bg-gray-50/40' : ''} ${isSelected ? 'bg-primary-light/40' : ''}`}>
                    
                    <td className="px-3 py-3">
                      <input
                        type="checkbox"
                        checked={isSelected}
                        onChange={() => toggleOne(r.oznaka)}
                        className="w-4 h-4 accent-primary" />
                      
                    </td>
                    <td className="px-4 py-3">
                      <div className="font-mono text-sm font-semibold text-gray-900">
                        {r.oznaka}
                      </div>
                      {r.barkod &&
                      <div className="font-mono text-[11px] text-gray-400 mt-0.5">
                          {r.barkod}
                        </div>
                      }
                    </td>
                    <td className="px-4 py-3 text-gray-900">{r.naziv}</td>
                    <td className="px-4 py-3">
                      <span
                        className={`inline-flex items-center px-2 py-0.5 text-xs font-medium rounded-md border ${KLASA_COLORS[r.klasa]}`}>
                        
                        {r.klasa}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-right">
                      <span className="text-sm font-semibold text-gray-900">
                        {r.uMagacinu}
                      </span>
                      <span className="text-xs text-gray-400 ml-1">kom</span>
                    </td>
                    <td className="px-4 py-3 text-right">
                      {r.naMasinama.length > 0 ?
                      <button
                        onClick={() =>
                        setExpanded(isExpanded ? null : r.oznaka)
                        }
                        className="inline-flex items-center gap-1 text-sm font-semibold text-primary hover:underline">
                        
                          <ChevronRight
                          className={`w-3 h-3 transition-transform ${isExpanded ? 'rotate-90' : ''}`} />
                        
                          {totalNaMas}
                          <span className="text-xs text-gray-400 font-normal">
                            ({r.naMasinama.length})
                          </span>
                        </button> :

                      <span className="text-gray-300">—</span>
                      }
                    </td>
                    <td className="px-4 py-3 text-right">
                      <span
                        className={`text-base font-bold ${ukupno === 0 ? 'text-red-600' : isLow ? 'text-amber-600' : 'text-gray-900'}`}>
                        
                        {ukupno}
                      </span>
                      {r.minKolicina > 0 &&
                      <div className="text-[11px] text-gray-400 mt-0.5">
                          min. {r.minKolicina}
                        </div>
                      }
                    </td>
                    <td className="px-4 py-3">
                      <StatusPill status={r.status} />
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center justify-end gap-1">
                        <button
                          title="Štampa nalepnice"
                          className="p-1.5 text-gray-400 hover:text-primary hover:bg-primary-light rounded transition-colors">
                          
                          <Printer className="w-4 h-4" />
                        </button>
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
                  </tr>
                  {isExpanded && r.naMasinama.length > 0 &&
                  <tr className="bg-primary-light/15 border-b border-gray-100">
                      <td></td>
                      <td colSpan={8} className="px-4 py-3">
                        <div className="text-[11px] font-semibold tracking-wider text-gray-500 uppercase mb-2">
                          Raspored po mašinama
                        </div>
                        <div className="flex flex-wrap gap-2">
                          {r.naMasinama.map((m) =>
                        <div
                          key={m.masina}
                          className="flex items-center gap-2 px-3 py-1.5 bg-white border border-gray-200 rounded-md text-sm">
                          
                              <span className="font-mono text-xs text-gray-500">
                                {m.masina}
                              </span>
                              <span className="font-bold text-gray-900">
                                {m.kolicina}
                              </span>
                              <span className="text-xs text-gray-400">kom</span>
                            </div>
                        )}
                        </div>
                      </td>
                    </tr>
                  }
                </Fragment>);

            })}
          </tbody>
        </table>
      </div>
    </div>);

}