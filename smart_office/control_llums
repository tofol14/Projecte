// Variables per l'estació meteorològica
"timestamp_anterior" := "timestamp_actual";  // Guardar timestamp anterior
"timestamp_actual" := "DB_Meteo".timestamp;  // Nou timestamp

// Verificar si les dades són fresques (menys de 30s)
"dades_valides" := ("timestamp_actual" - "timestamp_anterior") <= 30;

// Llegeix els valors meteorològics si són vàlids
IF "dades_valides" THEN
    "llum_exterior" := "DB_Meteo".llum_exterior;
    "estat_cel" := "DB_Meteo".estat_cel;
    "temperatura_exterior" := "DB_Meteo".temperatura_exterior;
    "humitat" := "DB_Meteo".humitat;
END_IF;

// Llegeix els valors crus de les entrades analògiques
"raw_setpoint_jefe" := "setpoint_jefe"; // Entrada analògica del potenciòmetre del setpoint
"raw_sensor_jefe" := "sensor_jefe";   // Entrada analògica del potenciòmetre del sensor

// Normalitza els valors (0.0 a 1.0)
"normalitzat_setpoint_jefe" := NORM_X(MIN := 0.0, VALUE := "raw_setpoint_jefe", MAX := 27648);
"normalitzat_sensor_jefe" := NORM_X(MIN := 0.0, VALUE := "raw_sensor_jefe", MAX := 27648);

// Escala els valors (0 a 6000)
"escalat_setpoint_jefe" := SCALE_X(MIN := 0.0, VALUE := "normalitzat_setpoint_jefe", MAX := 6000.0);
"escalat_sensor_jefe" := SCALE_X(MIN := 0.0, VALUE := "normalitzat_sensor_jefe", MAX := 6000.0);

// Factor de compensació segons condicions meteorològiques
IF "dades_valides" THEN
    CASE "estat_cel" OF
        0:  // Cel clar
            "factor_compensacio" := 1.0;
            IF "llum_exterior" > 5000.0 THEN
                "factor_compensacio" := 0.8;  // Reduïm si hi ha molta llum natural
            END_IF;
            
        1:  // Parcialment núvol
            "factor_compensacio" := 1.2;
            
        2:  // Molt núvol
            "factor_compensacio" := 1.5;
            
        ELSE
            "factor_compensacio" := 1.0;
    END_CASE;
    
    // Ajust addicional per humitat (la humitat alta pot reduir la visibilitat)
    IF "humitat" > 80.0 THEN
        "factor_compensacio" := "factor_compensacio" * 1.1;
    END_IF;
ELSE
    // Si les dades no són vàlides, utilitzem factor per defecte
    "factor_compensacio" := 1.0;
END_IF;

CASE "arrays".Variables_int[2] OF
    1:  // Mode automàtic amb compensació meteorològica
        IF "escalat_sensor_jefe" >= "escalat_setpoint_jefe" THEN
            "led_intensitat_jefe" := 0.0;
        ELSE
            IF "escalat_setpoint_jefe" > 0.0 THEN
                // Càlcul amb compensació meteorològica
                "diferencia_llum" := "escalat_setpoint_jefe" - "escalat_sensor_jefe";
                "compensacio_meteo" := "diferencia_llum" * "factor_compensacio";
                
                IF "dades_valides" AND "llum_exterior" > 5000.0 THEN
                    // Redueix la intensitat si hi ha molta llum natural
                    "led_intensitat_jefe" := ("compensacio_meteo" * 80.0) / "escalat_setpoint_jefe";
                ELSE
                    "led_intensitat_jefe" := ("compensacio_meteo" * 100.0) / "escalat_setpoint_jefe";
                END_IF;
                
                // Limitar la sortida entre 0 i 100%
                IF "led_intensitat_jefe" > 100.0 THEN
                    "led_intensitat_jefe" := 100.0;
                ELSIF "led_intensitat_jefe" < 0.0 THEN
                    "led_intensitat_jefe" := 0.0;
                END_IF;
            ELSE
                "led_intensitat_jefe" := 0.0;
            END_IF;
        END_IF;
        
    2:  // Baixa llum (relax)
        "escena_intensitat" := (1500 * 100) / 6000; // Calcula el percentatge segons 6000 lux màxim  
        "led_intensitat_jefe" := "escena_intensitat";
    3:  // Baixa llum (relax)
        "escena_intensitat" := (4000 * 100) / 6000;
        "led_intensitat_jefe" := "escena_intensitat";
    4:  // Alta lluminositat (reunió intensa)
        "escena_intensitat" := 100; // 6000 lux és igual al 100% de lluminositat
        "led_intensitat_jefe" := "escena_intensitat";
    ELSE
        "led_intensitat_jefe" := 0;
        
END_CASE;

IF "switch_estat" THEN
    // Deixa la intensitat calculada pel mode automàtic o les altres escenes
    "led_intensitat_jefe" := "led_intensitat_jefe";
ELSE
    // Apaga les llums si el switch està desactivat
    "led_intensitat_jefe" := 0;
END_IF;
// Assignació del valor calculat a una memòria per control LED
"node_red1" := "led_intensitat_jefe";
"arrays".Variables_int[1] := INT_TO_WORD(TRUNC("node_red1"));