import '../models/propietario_model.dart';

final List<Map<String, dynamic>> propietariosFake = [
  {
    'condominio': 'Los Alamos',
    'casa': 1,
    'password': '1234',
    'personas': [
      'Douglas Acosta Castillo',
      'María Cristina Soruco',
      'Leonardo Acosta Soruco',
      'Carlos Andrés Acosta',
    ],
  },
  {
    'condominio': 'El Bosque',
    'casa': 2,
    'password': '5678',
    'personas': [
      'Carlos Acosta',
      'Lucía Romero'],
  },
];

/// Busca un propietario que coincida con los datos ingresados
PropietarioModel? buscarPropietario(String condominio, int casa, String password) {
  final encontrado = propietariosFake.firstWhere(
    (prop) =>
        prop['condominio'].toLowerCase() == condominio.toLowerCase() &&
        prop['casa'] == casa &&
        prop['password'] == password,
    orElse: () => {},
  );

  if (encontrado.isEmpty) return null;

  return PropietarioModel(
    condominio: encontrado['condominio'],
    casa: Casa(nombre: 'Casa', numero: encontrado['casa']),
    codigoCasa: '000',
    personas: List<String>.from(encontrado['personas']),
  );
}
