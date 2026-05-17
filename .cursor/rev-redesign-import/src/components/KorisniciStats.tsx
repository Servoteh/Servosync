import React, { Component } from 'react';
import {
  Users,
  CheckCircle2,
  ShieldCheck,
  UserCheck,
  Briefcase,
  EyeOff,
  UserCog } from
'lucide-react';
interface Stat {
  label: string;
  value: number;
  icon: ComponentType<{
    className?: string;
  }>;
  bg: string;
  iconColor: string;
  active?: boolean;
}
interface Props {
  activeFilter: string;
  onFilterChange: (id: string) => void;
}
export function KorisniciStats({ activeFilter, onFilterChange }: Props) {
  const stats: (Stat & {
    id: string;
  })[] = [
  {
    id: 'all',
    label: 'Ukupno',
    value: 12,
    icon: Users,
    bg: 'bg-gray-50',
    iconColor: 'text-gray-500'
  },
  {
    id: 'active',
    label: 'Aktivni',
    value: 12,
    icon: CheckCircle2,
    bg: 'bg-green-50',
    iconColor: 'text-green-500'
  },
  {
    id: 'admin',
    label: 'Admin',
    value: 3,
    icon: ShieldCheck,
    bg: 'bg-purple-50',
    iconColor: 'text-purple-500'
  },
  {
    id: 'hr',
    label: 'HR',
    value: 1,
    icon: UserCheck,
    bg: 'bg-emerald-50',
    iconColor: 'text-emerald-500'
  },
  {
    id: 'pm',
    label: 'PM / Lead PM',
    value: 1,
    icon: Briefcase,
    bg: 'bg-blue-50',
    iconColor: 'text-blue-500'
  },
  {
    id: 'menadzment',
    label: 'Menadžment',
    value: 7,
    icon: UserCog,
    bg: 'bg-amber-50',
    iconColor: 'text-amber-500'
  },
  {
    id: 'viewer',
    label: 'Viewer',
    value: 0,
    icon: EyeOff,
    bg: 'bg-gray-50',
    iconColor: 'text-gray-400'
  }];

  return (
    <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-7 gap-2.5">
      {stats.map((s) => {
        const Icon = s.icon;
        const active = activeFilter === s.id;
        return (
          <button
            key={s.id}
            onClick={() => onFilterChange(s.id)}
            className={`flex items-center gap-3 p-3 border rounded-lg shadow-sm transition-all text-left ${active ? 'bg-primary-light border-primary/40 ring-2 ring-primary/15' : 'bg-white border-gray-200 hover:border-gray-300 hover:shadow'}`}>
            
            <div
              className={`w-9 h-9 ${s.bg} rounded-lg flex items-center justify-center shrink-0`}>
              
              <Icon className={`w-4.5 h-4.5 ${s.iconColor}`} />
            </div>
            <div className="min-w-0">
              <div
                className={`text-[10px] font-bold tracking-wider uppercase ${active ? 'text-primary/80' : 'text-gray-500'}`}>
                
                {s.label}
              </div>
              <div
                className={`text-xl font-bold leading-none ${active ? 'text-primary' : 'text-gray-900'}`}>
                
                {s.value}
              </div>
            </div>
          </button>);

      })}
    </div>);

}