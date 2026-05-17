import React from 'react';
import { Search, RefreshCw, Plus, Info } from 'lucide-react';
interface Props {
  search: string;
  onSearch: (s: string) => void;
  uloga: string;
  onUlogaChange: (s: string) => void;
  status: string;
  onStatusChange: (s: string) => void;
}
export function KorisniciToolbar({
  search,
  onSearch,
  uloga,
  onUlogaChange,
  status,
  onStatusChange
}: Props) {
  return (
    <div className="bg-white border border-gray-200 rounded-lg shadow-sm p-3 flex flex-wrap items-end gap-3">
      <div className="flex-1 min-w-[220px]">
        <label className="text-[10px] font-bold text-gray-500 tracking-wider">
          PRETRAGA
        </label>
        <div className="relative mt-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input
            type="text"
            value={search}
            onChange={(e) => onSearch(e.target.value)}
            placeholder="Pretraga po imenu, email-u, timu..."
            className="w-full pl-9 pr-3 py-2 text-sm border border-gray-300 rounded-md focus:ring-2 focus:ring-primary focus:border-primary outline-none bg-gray-50" />
          
        </div>
      </div>

      <div>
        <label className="text-[10px] font-bold text-gray-500 tracking-wider">
          ULOGA
        </label>
        <select
          value={uloga}
          onChange={(e) => onUlogaChange(e.target.value)}
          className="mt-1 px-3 py-2 text-sm border border-gray-300 rounded-md focus:ring-2 focus:ring-primary outline-none bg-white min-w-[140px]">
          
          <option value="all">Sve uloge</option>
          <option value="admin">Admin</option>
          <option value="hr">HR</option>
          <option value="pm">PM / Lead PM</option>
          <option value="menadzment">Menadžment</option>
          <option value="viewer">Viewer</option>
        </select>
      </div>

      <div>
        <label className="text-[10px] font-bold text-gray-500 tracking-wider">
          STATUS
        </label>
        <select
          value={status}
          onChange={(e) => onStatusChange(e.target.value)}
          className="mt-1 px-3 py-2 text-sm border border-gray-300 rounded-md focus:ring-2 focus:ring-primary outline-none bg-white min-w-[140px]">
          
          <option value="all">Svi statusi</option>
          <option value="aktivan">Aktivan</option>
          <option value="neaktivan">Neaktivan</option>
          <option value="suspendovan">Suspendovan</option>
        </select>
      </div>

      <div className="ml-auto flex items-center gap-2">
        <div className="hidden lg:flex items-center gap-1.5 px-2.5 py-1.5 bg-blue-50 border border-blue-200 rounded-md text-[11px] text-blue-700">
          <Info className="w-3.5 h-3.5" />
          Nove uloge: kroz Supabase SQL Editor
        </div>
        <button className="flex items-center gap-2 px-3 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50">
          <RefreshCw className="w-4 h-4 text-gray-500" />
          Osveži
        </button>
        <button className="flex items-center gap-2 px-4 py-2 text-sm font-semibold text-white bg-primary rounded-md hover:bg-primary-hover shadow-sm">
          <Plus className="w-4 h-4" />
          Pozovi korisnika
        </button>
      </div>
    </div>);

}