import React from 'react';
const ROLE_STYLES: Record<string, string> = {
  ADMIN: 'bg-purple-50 text-purple-700 border-purple-200',
  HR: 'bg-emerald-50 text-emerald-700 border-emerald-200',
  'LEAD PM': 'bg-blue-50 text-blue-700 border-blue-200',
  PM: 'bg-blue-50 text-blue-700 border-blue-200',
  MENADŽMENT: 'bg-amber-50 text-amber-700 border-amber-200',
  VIEWER: 'bg-gray-50 text-gray-600 border-gray-200'
};
export function RoleBadge({ role }: {role: string;}) {
  const styles = ROLE_STYLES[role] || 'bg-gray-50 text-gray-700 border-gray-200';
  return (
    <span
      className={`inline-flex items-center px-2 py-0.5 text-[11px] font-bold tracking-wider uppercase border rounded ${styles}`}>
      
      {role}
    </span>);

}