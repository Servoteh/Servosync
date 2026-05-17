import React from 'react';
import { AlertTriangle, Pencil, Trash2 } from 'lucide-react';
import { RoleBadge } from './RoleBadge';
export interface UserRow {
  id: string;
  ime: string;
  email: string;
  uloga: string;
  tim: string | null;
  projekat: string;
  status: 'Aktivan' | 'Neaktivan' | 'Suspendovan';
  dodato: string;
  warning?: boolean;
}
const MOCK: UserRow[] = [
{
  id: '1',
  ime: 'Nenad Jaraković',
  email: 'nenad.jarakovic@servoteh.com',
  uloga: 'ADMIN',
  tim: 'Uprava',
  projekat: 'Sve',
  status: 'Aktivan',
  dodato: '18. 4. 2026.'
},
{
  id: '2',
  ime: 'Nevena Knežević',
  email: 'nevena.knezevic@servoteh.com',
  uloga: 'ADMIN',
  tim: 'Administracija',
  projekat: 'Sve',
  status: 'Aktivan',
  dodato: '18. 4. 2026.',
  warning: true
},
{
  id: '3',
  ime: 'Milovan Srejić',
  email: 'srejicmilovan@gmail.com',
  uloga: 'ADMIN',
  tim: 'Administracija',
  projekat: 'Sve',
  status: 'Aktivan',
  dodato: '21. 4. 2026.',
  warning: true
},
{
  id: '4',
  ime: 'Nikola Mrkajić',
  email: 'nikola.mrkajic@servoteh.com',
  uloga: 'HR',
  tim: 'Administracija',
  projekat: 'Sve',
  status: 'Aktivan',
  dodato: '18. 4. 2026.',
  warning: true
},
{
  id: '5',
  ime: '—',
  email: 'milan.stojadinovic@servoteh.com',
  uloga: 'LEAD PM',
  tim: null,
  projekat: '—',
  status: 'Aktivan',
  dodato: '16. 4. 2026.'
},
{
  id: '6',
  ime: '—',
  email: 'dusko.kostic@servoteh.com',
  uloga: 'MENADŽMENT',
  tim: null,
  projekat: '—',
  status: 'Aktivan',
  dodato: '24. 4. 2026.'
},
{
  id: '7',
  ime: 'Nenad2 Jaraković',
  email: 'jarakovic@gmail.com',
  uloga: 'MENADŽMENT',
  tim: 'Uprava',
  projekat: '—',
  status: 'Aktivan',
  dodato: '21. 4. 2026.',
  warning: true
},
{
  id: '8',
  ime: 'Miljan Nikodijević',
  email: 'miljan.nikodijevic@servoteh.com',
  uloga: 'MENADŽMENT',
  tim: 'Menadžment',
  projekat: '—',
  status: 'Aktivan',
  dodato: '22. 4. 2026.',
  warning: true
}];

interface Props {
  search: string;
  uloga: string;
  status: string;
}
export function KorisniciTable({ search, uloga, status }: Props) {
  const filtered = MOCK.filter((u) => {
    if (uloga !== 'all') {
      const map: Record<string, string[]> = {
        admin: ['ADMIN'],
        hr: ['HR'],
        pm: ['PM', 'LEAD PM'],
        menadzment: ['MENADŽMENT'],
        viewer: ['VIEWER']
      };
      if (map[uloga] && !map[uloga].includes(u.uloga)) return false;
    }
    if (status !== 'all' && u.status.toLowerCase() !== status) return false;
    if (
    search &&
    !`${u.ime} ${u.email} ${u.tim ?? ''}`.
    toLowerCase().
    includes(search.toLowerCase()))

    return false;
    return true;
  });
  return (
    <div className="bg-white border border-gray-200 rounded-lg shadow-sm overflow-hidden">
      <div className="px-4 py-2.5 border-b border-gray-200 bg-gray-50 flex items-center justify-between text-xs">
        <span className="text-gray-600">
          Prikazano{' '}
          <span className="font-bold text-gray-900">{filtered.length}</span> od{' '}
          <span className="font-bold">{MOCK.length}</span> korisnika
        </span>
        <span className="text-gray-500">
          Sortirano po:{' '}
          <span className="font-medium text-gray-700">Datum dodavanja ↓</span>
        </span>
      </div>

      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="bg-gray-50/60 border-b border-gray-200 text-left text-[11px] tracking-wider uppercase text-gray-600">
              <th className="px-4 py-3 font-semibold">Ime i prezime</th>
              <th className="px-4 py-3 font-semibold">Email</th>
              <th className="px-4 py-3 font-semibold">Uloga</th>
              <th className="px-4 py-3 font-semibold">Tim</th>
              <th className="px-4 py-3 font-semibold">Projekat</th>
              <th className="px-4 py-3 font-semibold">Status</th>
              <th className="px-4 py-3 font-semibold">Dodato</th>
              <th className="px-4 py-3 font-semibold text-right">Akcije</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {filtered.map((u) =>
            <tr
              key={u.id}
              className="hover:bg-gray-50/60 transition-colors group">
              
                <td className="px-4 py-3">
                  <div className="flex items-center gap-2">
                    {u.ime !== '—' ?
                  <div className="flex items-center justify-center w-7 h-7 bg-gray-100 text-gray-600 text-[10px] font-bold rounded-full shrink-0">
                        {u.ime.
                    split(' ').
                    map((s) => s[0]).
                    join('').
                    slice(0, 2)}
                      </div> :

                  <div className="flex items-center justify-center w-7 h-7 bg-amber-50 text-amber-600 rounded-full shrink-0">
                        <AlertTriangle className="w-3.5 h-3.5" />
                      </div>
                  }
                    <span
                    className={`font-medium ${u.ime === '—' ? 'text-gray-400 italic' : 'text-gray-900'}`}>
                    
                      {u.ime === '—' ? 'Profil nepotpun' : u.ime}
                    </span>
                    {u.warning && u.ime !== '—' &&
                  <AlertTriangle
                    className="w-3.5 h-3.5 text-amber-500"
                    title="Profil zahteva pažnju" />

                  }
                  </div>
                </td>
                <td className="px-4 py-3 font-mono text-xs text-gray-700">
                  {u.email}
                </td>
                <td className="px-4 py-3">
                  <RoleBadge role={u.uloga} />
                </td>
                <td className="px-4 py-3 text-gray-700">
                  {u.tim ?? <span className="text-gray-400">—</span>}
                </td>
                <td className="px-4 py-3 text-gray-700">{u.projekat}</td>
                <td className="px-4 py-3">
                  <span className="inline-flex items-center gap-1.5 px-2 py-0.5 text-xs font-medium text-green-700 bg-green-50 border border-green-200 rounded">
                    <span className="w-1.5 h-1.5 rounded-full bg-green-500"></span>
                    {u.status}
                  </span>
                </td>
                <td className="px-4 py-3 text-gray-600 text-xs">{u.dodato}</td>
                <td className="px-4 py-3">
                  <div className="flex items-center justify-end gap-1">
                    <button
                    title="Izmeni"
                    className="p-1.5 text-gray-500 hover:text-primary hover:bg-primary-light rounded-md transition-colors">
                    
                      <Pencil className="w-3.5 h-3.5" />
                    </button>
                    <button
                    title="Obriši"
                    className="p-1.5 text-gray-500 hover:text-red-600 hover:bg-red-50 rounded-md transition-colors">
                    
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>);

}