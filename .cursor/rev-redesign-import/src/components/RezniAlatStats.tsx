import React from 'react';
import {
  Scissors,
  CheckCircle2,
  Cog,
  Warehouse,
  AlertTriangle } from
'lucide-react';
type StatProps = {
  label: string;
  value: string | number;
  hint?: string;
  icon: React.ElementType;
  tone?: 'default' | 'warning' | 'success';
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
  tone === 'success' ?
  'text-green-600 bg-green-100' :
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
export function RezniAlatStats() {
  return (
    <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
      <StatCard
        label="Ukupno šifri"
        value={142}
        hint="u katalogu"
        icon={Scissors} />
      
      <StatCard
        label="Aktivne"
        value={128}
        hint="dostupne"
        icon={CheckCircle2}
        tone="success" />
      
      <StatCard label="Na mašinama" value={86} hint="komada" icon={Cog} />
      <StatCard
        label="U magacinu"
        value={1240}
        hint="komada"
        icon={Warehouse} />
      
      <StatCard
        label="Niska zaliha"
        value={9}
        hint="ispod minimuma"
        icon={AlertTriangle}
        tone="warning" />
      
    </div>);

}