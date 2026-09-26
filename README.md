# Fase 2 - Lenguaje Procedimental: Administración de Bases de Datos

Este repositorio contiene la consolidación de los scripts SQL desarrollados como parte del componente práctico de la Fase 2 del curso de Administración de Bases de Datos. Todo el código fue implementado y probado en el entorno de Oracle APEX.

## 📌 Datos del Estudiante
* **Autor:** Bryan Alexander Campuzano Giraldo
* **Curso:** Administración de Bases de Datos (202016902)
* **Institución:** Universidad Nacional Abierta y a Distancia (UNAD) - ECBTI
* **Fecha:** Septiembre de 2026

## 🎯 Propósito del Proyecto
El objetivo de esta fase es resolver problemáticas de rendimiento y escalabilidad en un esquema de base de datos de retail (RetailData) mediante la aplicación de técnicas de optimización y **Lenguaje Procedimental (PL/SQL)**. 

Se implementaron estructuras avanzadas en el motor de la base de datos para centralizar la lógica de negocio, garantizar la integridad de los datos y optimizar los tiempos de respuesta.

## 🛠️ Tecnologías y Conceptos Aplicados
* **Motor de BD:** Oracle Database (vía Oracle APEX)
* **Lenguaje:** SQL y PL/SQL
* **Estrategias implementadas:**
  * **Optimización de consultas:** Rediseño de queries eliminando subconsultas escalares apoyado en planes de ejecución (`EXPLAIN PLAN`).
  * **Particionamiento de tablas:** Uso de `PARTITION BY RANGE` para datos históricos (pedidos por año) mejorando la lectura.
  * **Vistas Materializadas:** Creación de pre-cálculos físicos (`REFRESH COMPLETE`) orientados a sistemas de reporte (OLAP).
  * **Procedimientos Almacenados y Funciones:** Encapsulamiento de lógica transaccional, cálculos matemáticos masivos y uso de parámetros `IN/OUT`.
  * **Disparadores (Triggers):** Automatización a nivel de fila (`FOR EACH ROW`) para crear auditorías silenciosas de inventarios y precios.
  * **Cursores Explícitos:** Manejo iterativo de registros para procesamientos específicos y limpiezas de datos (pedidos pendientes).
  * **Manejo de Excepciones:** Control de flujos de error (ej. duplicidad de datos) para evitar caídas del sistema y garantizar operaciones seguras.