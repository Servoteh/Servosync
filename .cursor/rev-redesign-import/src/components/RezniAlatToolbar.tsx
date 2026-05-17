import React from 'react';
import { Search, Plus, Printer, ScanLine, Undo2, Download } from 'lucide-react';
type RezniAlatToolbarProps = {
  search: string;
  onSearch: (v: string) => void;
  klasa: string;
  onKlasaChange: (v: string) => void;
  masina: string;
  onMasinaChange: (v: string) => void;
  status: string;
  onStatusChange: (v: string) => void;
  selectedCount: number;
};
export function RezniAlatToolbar({
  search,
  onSearch,
  klasa,
  onKlasaChange,
  masina,
  onMasinaChange,
  status,
  onStatusChange,
  selectedCount
}: RezniAlatToolbarProps) {
  return (
    <div className="bg-gray-50 border border-gray-200 rounded-lg p-3 space-y-3">
      {/* Filteri */}
      <div className="flex items-center gap-2 flex-wrap">
        <div className="relative flex-1 min-w-[260px]">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input
            type="text"
            value={search}
            onChange={(e) => onSearch(e.target.value)}
            placeholder="Pretraga po oznaci, nazivu, klasi ili barkodu…"
            className="w-full pl-9 pr-3 py-2 text-sm bg-white border border-gray-200 rounded-md focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary" />
          
        </div>

        <select
          value={klasa}
          onChange={(e) => onKlasaChange(e.target.value)}
          className="px-3 py-2 text-sm bg-white border border-gray-200 rounded-md focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary min-w-[140px]">
          
          <option value="all">— Sve klase —</option>
          <option value="glodalo">Glodalo</option>
          <option value="burgija">Burgija</option>
          <option value="plocica">Pločica</option>
          <option value="urezivac">Urezivač</option>
          <option value="cep">Razvrtač</option>
        </select>

        <select
          value={masina}
          onChange={(e) => onMasinaChange(e.target.value)}
          className="px-3 py-2 text-sm bg-white border border-gray-200 rounded-md focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary min-w-[160px]">
          
          <option value="all">— Sve mašine —</option>
          <option value="cnc-01">CNC-01 Haas VF-2</option>
          <option value="cnc-02">CNC-02 Haas VF-3</option>
          <option value="cnc-03">CNC-03 DMG Mori</option>
          <option value="strug-01">Strug-01 Mazak</option>
        </select>

        <select
          value={status}
          onChange={(e) => onStatusChange(e.target.value)}
          className="px-3 py-2 text-sm bg-white border border-gray-200 rounded-md focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary min-w-[120px]">
          
          <option value="aktivne">Aktivne</option>
          <option value="povucene">Povučene</option>
          <option value="all">Sve</option>
        </select>
      </div>

      {/* Akcije */}
      <div className="flex items-center gap-2 flex-wrap">
        <button
          disabled={selectedCount === 0}
          className="flex items-center gap-2 px-3 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-md hover:bg-gray-50 transition-colors disabled:opacity-50 disabled:cursor-not-allowed">
          
          <Printer className="w-4 h-4" />
          Štampa odabranih
          {selectedCount > 0 &&
          <span className="px-1.5 py-0.5 bg-primary-light text-primary text-xs font-semibold rounded">
              {selectedCount}
            </span>
          }
        </button>

        <div className="h-6 w-px bg-gray-300 mx-1" />

        <button className="flex items-center gap-2 px-3 py-2 text-sm font-medium text-white bg-primary rounded-md hover:bg-primary-hover transition-colors shadow-sm">
          <ScanLine className="w-4 h-4" />
          Zaduženje (skener)
        </button>
        <button className="flex items-center gap-2 px-3 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 transition-colors">
          <Undo2 className="w-4 h-4" />
          Povraćaj (skener)
        </button>

        <div className="ml-auto flex items-center gap-2">
          <button className="flex items-center gap-2 px-3 py-2 text-sm font-medium text-green-700 bg-green-50 border border-green-200 rounded-md hover:bg-green-100 transition-colors">
            <Download className="w-4 h-4" />
            Excel
          </button>
          <button className="flex items-center gap-2 px-3 py-2 text-sm font-medium text-white bg-primary rounded-md hover:bg-primary-hover transition-colors shadow-sm">
            <Plus className="w-4 h-4" />
            Nova šifra
          </button>
        </div>
      </div>
    </div>);

}