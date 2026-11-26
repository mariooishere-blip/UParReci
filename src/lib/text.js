export const subjects = ['Srpski jezik','Matematika','Istorija','Geografija','Biologija','Hemija','Fizika','Engleski jezik','Informatika','Književnost','Ostalo']
export const types = ['Prepričavanje','Lektira','Sažetak','Beleške','Lekcija','Referat','Ostalo']
export const levels = ['Osnovna škola','Srednja škola']
export function normalizeText(value='') {
  return value.toLocaleLowerCase('sr-Latn').normalize('NFD').replace(/[\\u0300-\\u036f]/g,'')
    .replaceAll('đ','d').replaceAll('Đ','d')
}
export function gradeLabel(level, grade) { return `${grade}. razred · ${level || ''}` }
export function formatDate(value) {
  return new Intl.DateTimeFormat('sr-Latn', { dateStyle: 'medium' }).format(new Date(value))
}
