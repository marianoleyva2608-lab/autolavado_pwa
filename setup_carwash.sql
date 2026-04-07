-- Configuración de Tablas para Autolavado (PWA)
-- Ejecutar esto en el SQL Editor de Supabase

-- 1. Tabla de Servicios (Lavado Sencillo, Premium, Encerado, etc.)
CREATE TABLE cw_services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  price NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
  category TEXT DEFAULT 'lavado', -- lavado, estetica, extra
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Tabla de Trabajadores / Lavadores
CREATE TABLE cw_workers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  role TEXT DEFAULT 'washer', -- 'washer' (lavador), 'reception' (recepcion), 'admin' (caja)
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Tabla Principal de Tickets (Órdenes de Lavado)
CREATE TABLE cw_tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_number SERIAL UNIQUE,
  customer_name TEXT,
  vehicle_plate TEXT,
  vehicle_model TEXT,
  vehicle_color TEXT,
  
  -- queue (en espera), washing (en proceso), ready (listo para entrega), delivered (entregado al cliente)
  status TEXT DEFAULT 'queue' NOT NULL,
  
  -- pending (falta pagar), paid (ya pagó)
  payment_status TEXT DEFAULT 'pending' NOT NULL,
  
  total_amount NUMERIC(10, 2) DEFAULT 0.00,
  worker_assigned_id UUID REFERENCES cw_workers(id) ON DELETE SET NULL,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  completed_at TIMESTAMP WITH TIME ZONE
);

-- 4. Tabla de items dentro de un ticket (qué servicios compró)
CREATE TABLE cw_ticket_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id UUID REFERENCES cw_tickets(id) ON DELETE CASCADE,
  service_id UUID REFERENCES cw_services(id) ON DELETE RESTRICT,
  
  quantity INTEGER DEFAULT 1,
  price_at_time NUMERIC(10, 2) NOT NULL,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Habilitar actualizaciones en tiempo real (Supabase Realtime)
BEGIN;
  DROP PUBLICATION IF EXISTS cw_realtime;
  CREATE PUBLICATION cw_realtime FOR TABLE cw_tickets, cw_ticket_items, cw_workers, cw_services;
COMMIT;

-- (Opcional) Insertar algunos servicios por defecto para arrancar rápido
INSERT INTO cw_services (name, price, category) VALUES
  ('Lavado Sencillo (Auto)', 80.00, 'lavado'),
  ('Lavado Sencillo (Camioneta)', 100.00, 'lavado'),
  ('Lavado Sencillo (Moto)', 50.00, 'lavado'),
  ('Lavado Premium', 150.00, 'lavado'),
  ('Encerado Express', 80.00, 'estetica'),
  ('Lavado de Motor', 120.00, 'extra'),
  ('Aspirado y Limpieza de Interiores', 50.00, 'estetica');

-- Insertar un trabajador por defecto
INSERT INTO cw_workers (name, role) VALUES 
  ('Pedro (Lavador)', 'washer'),
  ('Maria (Caja)', 'admin');
