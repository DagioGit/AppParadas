#!/usr/bin/env bash
# Corre un comando; si falla, deja las últimas líneas como anotación de error en GitHub Actions
# (así se ven en la pestaña del run sin descargar el log completo).
"$@" 2>&1 | tee salida.log
estado=${PIPESTATUS[0]}
if [ "$estado" -ne 0 ]; then
  importante=$(grep -nE "error|Error|ERROR|What went wrong|FAILED|Exception|requires|incompatible|Could not|failed" salida.log | tail -n 40)
  [ -z "$importante" ] && importante=$(tail -n 40 salida.log)
  texto=$(printf '%s' "$importante" | cut -c1-300 | sed ':a;N;$!ba;s/%/%25/g;s/\r//g;s/\n/%0A/g')
  echo "::error title=Falló: $1 $2::$texto"
  ultimas=$(tail -n 25 salida.log | cut -c1-300 | sed ':a;N;$!ba;s/%/%25/g;s/\r//g;s/\n/%0A/g')
  echo "::error title=Final del log::$ultimas"
fi
exit "$estado"
