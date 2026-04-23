import { describe, expect, it } from 'vitest';
import {
  MACHINE_GROUPS,
  MACHINE_GROUPS_ROW_1,
  MACHINE_GROUPS_ROW_2,
  countMachinesPerGroup,
  filterMachinesByGroup,
  getMachineGroup,
  machineGroupLabel,
  sortMachinesByGroupOrder,
} from '../../src/lib/machineGroups.js';

/* Realistic uzorak iz bigtehn_machines_cache (skratio sam name-ove). */
const MACHINES = [
  { rj_code: '0.0',   name: 'Opšti nalog',              department_id: '00' },
  { rj_code: '1.10',  name: 'Sečenje testera',          department_id: '01' },
  { rj_code: '1.50',  name: 'Plazma',                    department_id: '01' },
  { rj_code: '1.71',  name: 'Apkant Hammerle 4100',      department_id: '15' },
  { rj_code: '1.72',  name: 'Apkant Hammerle 3100',      department_id: '15' },
  { rj_code: '2.1',   name: 'Strug Prvomajska',          department_id: '02' },
  { rj_code: '2.5',   name: 'CNC Strug Gildemeister',    department_id: '02' },
  { rj_code: '3.10',  name: 'CNC Glodanje DMU 50T TNC1', department_id: '03' },
  { rj_code: '3.21',  name: 'CNC-GLODANJE TOS WHN 13',   department_id: '03' },
  { rj_code: '3.22',  name: 'CNC-GLODANJE TOS WHN 13 H', department_id: '03' },
  { rj_code: '3.50',  name: 'Štos',                       department_id: '03' },
  { rj_code: '4.1',   name: 'Bravari-Savijanje',         department_id: '04' },
  { rj_code: '4.11',  name: 'Manuelno bušenje',           department_id: '04' },
  { rj_code: '4.12',  name: 'Radijalna bušilica',         department_id: '04' },
  { rj_code: '4.2',   name: 'Zavarivanje MIG/MAG',        department_id: '04' },
  { rj_code: '4.3',   name: 'Zavarivanje REL',           department_id: '04' },
  { rj_code: '4.4',   name: 'Zavarivanje TIG',           department_id: '04' },
  { rj_code: '5.1',   name: 'Farbanje',                   department_id: '05' },
  { rj_code: '5.4',   name: 'Niklovanje',                 department_id: '05' },
  { rj_code: '5.9',   name: 'Graviranje',                 department_id: '13' },
  { rj_code: '5.11',  name: 'Površinska zaštita',         department_id: '09' },
  { rj_code: '6.1.1', name: 'Brušenje Studer',            department_id: '06' },
  { rj_code: '6.8',   name: 'Laser-Graviranje',           department_id: '13' },
  { rj_code: '7.3',   name: 'Kalenje',                    department_id: '07' },
  { rj_code: '7.5',   name: 'Ispravljanje',               department_id: '14' },
  { rj_code: '8.1',   name: 'Montaža',                    department_id: '08' },
  { rj_code: '8.2',   name: 'Ručni radovi-Ažistiranje',   department_id: '08' },
  { rj_code: '8.3',   name: 'Završna Kontrola',           department_id: '08' },
  { rj_code: '8.4',   name: 'Međufazna Kontrola',         department_id: '08' },
  { rj_code: '9.0',   name: 'Kooperacija',                department_id: '09' },
  { rj_code: '9.1',   name: 'Nabavka',                    department_id: '09' },
  { rj_code: '10.1',  name: 'Žičano erodiranje',          department_id: '10' },
  { rj_code: '10.5',  name: 'Probijačica',                department_id: '10' },
  { rj_code: '17.0',  name: 'CAM glodanje',               department_id: '17', no_procedure: true },
  { rj_code: '17.1',  name: 'CAM struganje',              department_id: '17', no_procedure: true },
  { rj_code: '21.1',  name: '3D Štampanje Sindoh',        department_id: '21' },
];

describe('MACHINE_GROUPS konfiguracija', () => {
  it('ima jedinstvene id-ove', () => {
    const ids = MACHINE_GROUPS.map((g) => g.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  it('"Sve" je prvi i "Ostalo" je poslednji', () => {
    expect(MACHINE_GROUPS[0].id).toBe('all');
    expect(MACHINE_GROUPS[MACHINE_GROUPS.length - 1].id).toBe('ostalo');
  });

  it('Red 1 ima 6 grupa po dogovorenom redosledu', () => {
    expect(MACHINE_GROUPS_ROW_1.map((g) => g.id)).toEqual([
      'all', 'glodanje', 'struganje', 'brusenje', 'erodiranje', 'azistiranje',
    ]);
  });

  it('Red 2 ima 5 grupa po dogovorenom redosledu', () => {
    expect(MACHINE_GROUPS_ROW_2.map((g) => g.id)).toEqual([
      'secenje_savijanje', 'bravarsko', 'farbanje', 'cam', 'ostalo',
    ]);
  });

  it('svaka grupa ima row 1 ili 2', () => {
    for (const g of MACHINE_GROUPS) {
      expect([1, 2]).toContain(g.row);
    }
  });
});

describe('getMachineGroup — osnovne grupe', () => {
  it('Glodanje: CELA dept 03, uključujući borvere (3.21/3.22) i Štos (3.50)', () => {
    expect(getMachineGroup({ rj_code: '3.10', department_id: '03' })).toBe('glodanje');
    expect(getMachineGroup({ rj_code: '3.21', department_id: '03' })).toBe('glodanje');
    expect(getMachineGroup({ rj_code: '3.22', department_id: '03' })).toBe('glodanje');
    expect(getMachineGroup({ rj_code: '3.50', department_id: '03' })).toBe('glodanje');
  });

  it('Struganje = dept 02', () => {
    expect(getMachineGroup({ rj_code: '2.1', department_id: '02' })).toBe('struganje');
    expect(getMachineGroup({ rj_code: '2.5', department_id: '02' })).toBe('struganje');
  });

  it('Brušenje = dept 06', () => {
    expect(getMachineGroup({ rj_code: '6.1.1', department_id: '06' })).toBe('brusenje');
  });

  it('Erodiranje = dept 10', () => {
    expect(getMachineGroup({ rj_code: '10.1', department_id: '10' })).toBe('erodiranje');
    expect(getMachineGroup({ rj_code: '10.5', department_id: '10' })).toBe('erodiranje');
  });

  it('Ažistiranje = SAMO 8.2 (ne cela dept 08)', () => {
    expect(getMachineGroup({ rj_code: '8.2', department_id: '08' })).toBe('azistiranje');
    /* Ostale mašine iz dept 08 (montaža, kontrola) padaju u "ostalo" */
    expect(getMachineGroup({ rj_code: '8.1', department_id: '08' })).toBe('ostalo');
    expect(getMachineGroup({ rj_code: '8.3', department_id: '08' })).toBe('ostalo');
    expect(getMachineGroup({ rj_code: '8.4', department_id: '08' })).toBe('ostalo');
  });

  it('Sečenje i savijanje = dept 01 + dept 15 (Apkant)', () => {
    expect(getMachineGroup({ rj_code: '1.10', department_id: '01' })).toBe('secenje_savijanje');
    expect(getMachineGroup({ rj_code: '1.50', department_id: '01' })).toBe('secenje_savijanje');
    expect(getMachineGroup({ rj_code: '1.71', department_id: '15' })).toBe('secenje_savijanje');
    expect(getMachineGroup({ rj_code: '1.72', department_id: '15' })).toBe('secenje_savijanje');
  });

  it('Bravarsko = 4.1, 4.11, 4.12 (savijanje+bušenje) + 4.2/4.3/4.4 (zavarivanje)', () => {
    expect(getMachineGroup({ rj_code: '4.1', department_id: '04' })).toBe('bravarsko');
    expect(getMachineGroup({ rj_code: '4.11', department_id: '04' })).toBe('bravarsko');
    expect(getMachineGroup({ rj_code: '4.12', department_id: '04' })).toBe('bravarsko');
    expect(getMachineGroup({ rj_code: '4.2', department_id: '04' })).toBe('bravarsko');
    expect(getMachineGroup({ rj_code: '4.3', department_id: '04' })).toBe('bravarsko');
    expect(getMachineGroup({ rj_code: '4.4', department_id: '04' })).toBe('bravarsko');
  });

  it('Farbanje = cela dept 05 + 5.11', () => {
    expect(getMachineGroup({ rj_code: '5.1', department_id: '05' })).toBe('farbanje');
    expect(getMachineGroup({ rj_code: '5.4', department_id: '05' })).toBe('farbanje');
    expect(getMachineGroup({ rj_code: '5.11', department_id: '09' })).toBe('farbanje');
  });

  it('CAM programiranje = dept 17', () => {
    expect(getMachineGroup({ rj_code: '17.0', department_id: '17' })).toBe('cam');
    expect(getMachineGroup({ rj_code: '17.1', department_id: '17' })).toBe('cam');
  });
});

describe('getMachineGroup — Ostalo (fallback)', () => {
  it('Termička (dept 07) → Ostalo', () => {
    expect(getMachineGroup({ rj_code: '7.3', department_id: '07' })).toBe('ostalo');
  });

  it('3D štampa (dept 21) → Ostalo', () => {
    expect(getMachineGroup({ rj_code: '21.1', department_id: '21' })).toBe('ostalo');
  });

  it('Kooperacija/Nabavka (9.0/9.1) → Ostalo', () => {
    expect(getMachineGroup({ rj_code: '9.0', department_id: '09' })).toBe('ostalo');
    expect(getMachineGroup({ rj_code: '9.1', department_id: '09' })).toBe('ostalo');
  });

  it('Opšti nalog 0.0 → Ostalo', () => {
    expect(getMachineGroup({ rj_code: '0.0', department_id: '00' })).toBe('ostalo');
  });

  it('Graviranje/Ispravljanje → Ostalo', () => {
    expect(getMachineGroup({ rj_code: '5.9', department_id: '13' })).toBe('ostalo');
    expect(getMachineGroup({ rj_code: '6.8', department_id: '13' })).toBe('ostalo');
    expect(getMachineGroup({ rj_code: '7.5', department_id: '14' })).toBe('ostalo');
  });

  it('Montaža i kontrola (8.1/8.3/8.4) → Ostalo (samo 8.2 je Ažistiranje)', () => {
    expect(getMachineGroup({ rj_code: '8.1', department_id: '08' })).toBe('ostalo');
    expect(getMachineGroup({ rj_code: '8.3', department_id: '08' })).toBe('ostalo');
    expect(getMachineGroup({ rj_code: '8.4', department_id: '08' })).toBe('ostalo');
  });

  it('null/undefined/prazno → "ostalo" bez bacanja', () => {
    expect(getMachineGroup(null)).toBe('ostalo');
    expect(getMachineGroup(undefined)).toBe('ostalo');
    expect(getMachineGroup({})).toBe('ostalo');
  });
});

describe('filterMachinesByGroup', () => {
  it('"all" vraća sve', () => {
    expect(filterMachinesByGroup(MACHINES, 'all')).toHaveLength(MACHINES.length);
  });

  it('glodanje obuhvata borvere i Štos (svi iz dept 03)', () => {
    const r = filterMachinesByGroup(MACHINES, 'glodanje');
    expect(r.map((m) => m.rj_code).sort()).toEqual(['3.10', '3.21', '3.22', '3.50']);
  });

  it('sečenje_savijanje = dept 01 + dept 15', () => {
    const r = filterMachinesByGroup(MACHINES, 'secenje_savijanje');
    expect(r.map((m) => m.rj_code).sort()).toEqual(['1.10', '1.50', '1.71', '1.72']);
  });

  it('bravarsko = 6 mašina (4.1/4.11/4.12/4.2/4.3/4.4)', () => {
    const r = filterMachinesByGroup(MACHINES, 'bravarsko');
    expect(r.map((m) => m.rj_code).sort()).toEqual(['4.1', '4.11', '4.12', '4.2', '4.3', '4.4']);
  });

  it('azistiranje = samo 8.2', () => {
    const r = filterMachinesByGroup(MACHINES, 'azistiranje');
    expect(r.map((m) => m.rj_code)).toEqual(['8.2']);
  });

  it('ostalo obuhvata termičku, 3D, kooperaciju, graviranje, kontrolu…', () => {
    const r = filterMachinesByGroup(MACHINES, 'ostalo').map((m) => m.rj_code).sort();
    expect(r).toEqual(['0.0', '21.1', '5.9', '6.8', '7.3', '7.5', '8.1', '8.3', '8.4', '9.0', '9.1']);
  });

  it('nepoznat groupId → fallback na sve', () => {
    expect(filterMachinesByGroup(MACHINES, 'xxx')).toHaveLength(MACHINES.length);
  });
});

describe('countMachinesPerGroup', () => {
  it('"all" je ukupno; suma specifičnih + ostalo = ukupno', () => {
    const counts = countMachinesPerGroup(MACHINES);
    expect(counts.get('all')).toBe(MACHINES.length);
    let sum = 0;
    for (const g of MACHINE_GROUPS) {
      if (g.id === 'all') continue;
      sum += counts.get(g.id) || 0;
    }
    expect(sum).toBe(MACHINES.length);
  });

  it('konkretne brojke za uzorak', () => {
    const c = countMachinesPerGroup(MACHINES);
    expect(c.get('glodanje')).toBe(4);
    expect(c.get('struganje')).toBe(2);
    expect(c.get('brusenje')).toBe(1);
    expect(c.get('erodiranje')).toBe(2);
    expect(c.get('azistiranje')).toBe(1);
    expect(c.get('secenje_savijanje')).toBe(4);
    expect(c.get('bravarsko')).toBe(6);
    expect(c.get('farbanje')).toBe(3);
    expect(c.get('cam')).toBe(2);
    expect(c.get('ostalo')).toBe(11);
  });
});

describe('sortMachinesByGroupOrder', () => {
  it('mašine iste grupe ostaju zajedno, redom kako su grupe definisane', () => {
    const sorted = sortMachinesByGroupOrder(MACHINES);
    const order = (id) => MACHINE_GROUPS.findIndex((g) => g.id === id);
    let prev = -1;
    for (const m of sorted) {
      const o = order(getMachineGroup(m));
      expect(o).toBeGreaterThanOrEqual(prev);
      prev = o;
    }
  });

  it('unutar grupe sortira po rj_code natural', () => {
    const sub = MACHINES.filter((m) => m.department_id === '03');
    const sorted = sortMachinesByGroupOrder(sub);
    expect(sorted.map((m) => m.rj_code)).toEqual(['3.10', '3.21', '3.22', '3.50']);
  });
});

describe('machineGroupLabel', () => {
  it('vraća label po id-u', () => {
    expect(machineGroupLabel('glodanje')).toBe('Glodanje');
    expect(machineGroupLabel('secenje_savijanje')).toBe('Sečenje i savijanje');
    expect(machineGroupLabel('farbanje')).toBe('Farbanje i površinska zaštita');
    expect(machineGroupLabel('cam')).toBe('CAM programiranje');
    expect(machineGroupLabel('xxx')).toBe('Sve');
  });
});
