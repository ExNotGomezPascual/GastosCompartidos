const categories = <String>[
  'Servicios',
  'Mercado',
  'Arriendo',
  'Aseo',
  'Comida',
  'Transporte',
  'Alojamiento',
  'Entretenimiento',
  'Otros',
];

/// Palabras clave (sin tildes, en minúscula) que sugieren cada categoría.
const categoryKeywords = <String, List<String>>{
  'Servicios': [
    'gas', 'luz', 'agua', 'internet', 'epm', 'energia', 'servicio', 'servicios',
    'celular', 'plan', 'netflix', 'spotify', 'wifi', 'television', 'tv', 'cable',
    'administracion',
  ],
  'Mercado': [
    'mercado', 'd1', 'ara', 'exito', 'supermercado', 'compras', 'olimpica',
    'carulla', 'jumbo', 'tienda', 'fruver', 'verduras',
  ],
  'Arriendo': ['arriendo', 'alquiler', 'renta', 'arrendo'],
  'Aseo': ['aseo', 'limpieza', 'detergente', 'jabon', 'cocina', 'papel', 'escoba', 'trapero'],
  'Comida': [
    'comida', 'almuerzo', 'cena', 'desayuno', 'pizza', 'restaurante', 'domicilio',
    'rappi', 'hamburguesa', 'onces', 'pollo', 'mecato', 'cafe', 'empanadas', 'asado',
  ],
  'Transporte': [
    'taxi', 'uber', 'didi', 'gasolina', 'bus', 'transporte', 'peaje', 'lancha',
    'metro', 'parqueadero', 'tiquete', 'tiquetes', 'vuelo', 'pasajes', 'pasaje',
  ],
  'Alojamiento': ['hotel', 'hostal', 'airbnb', 'alojamiento', 'cabana', 'finca', 'glamping'],
  'Entretenimiento': [
    'cine', 'fiesta', 'entrada', 'entradas', 'concierto', 'trago', 'tragos',
    'cerveza', 'cervezas', 'licor', 'rumba', 'bolos', 'juego', 'paseo', 'tour',
  ],
};
