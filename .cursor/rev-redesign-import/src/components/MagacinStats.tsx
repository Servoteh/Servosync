import React from 'react';
import { Package, Wrench, Scissors, AlertTriangle } from 'lucide-react';
type StatProps = {
  label: string;
  value: string | number;
  hint?: string;
  icon: React.ElementType;
  tone?: 'default' | 'warning';
};
function StatCard({
  label,
  value,
  hint,
  icon: Icon,
  tone = 'default'
}: StatProps) {
  const toneClasses =
  tone === 'warning' ? 'bg-red-50 border-red-200' : 'bg-white border-gray-200';
  const iconTone =
  tone === 'warning' ?
  'text-red-600 bg-red-100' :
  'text-primary bg-primary-light';
  return (
    <div
      className={`flex items-center gap-3 px-4 py-3 border rounded-lg ${toneClasses}`}>
      
      <div
        className={`flex items-center justify-center w-10 h-10 rounded-md ${iconTone}`}>
        
        <Icon className="w-5 h-5" />
      </div>
      <div className="flex-1 min-w-0">
        <div className="text-[11px] font-semibold tracking-wider text-gray-500 uppercase">
          {label}
        </div>
        <div className="flex items-baseline gap-2">
          <span className="text-xl font-bold text-gray-900">{value}</span>
          {hint && <span className="text-xs text-gray-500">{hint}</span>}
        </div>
      </div>
    </div>);

}
export function MagacinStats() {
  return (
    <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
      <StatCard
        label="Ukupno artikala"
        value={247}
        hint="u magacinu"
        icon={Package} />
      
      <StatCard label="Ručni alat" value={183} hint="komada" icon={Wrench} />
      <StatCard label="Rezni alat" value={64} hint="lokacija" icon={Scissors} />
      <StatCard
        label="Nisko stanje"
        value={7}
        hint="potrebna nabavka"
        icon={AlertTriangle}
        tone="warning" />
      
    </div>);

}