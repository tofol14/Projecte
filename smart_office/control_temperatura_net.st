// BLOC 1: INICIALITZACIÓ I DEFINICIÓ DE VARIABLES
VAR_INPUT
    ClimaOn : Bool;         // Interruptor principal del sistema (0.0)
    BotoFred : Bool;        // Botó per activar mode refrigeració (des de Node-RED)
    BotoCalent : Bool;      // Botó per activar mode calefacció (des de Node-RED)
    SetPointNodeRED : Real; // Punt de consigna rebut de Node-RED (2.0)
    sensor_temp_jefe : Int; // Entrada del sensor de Factory IO (%IW40)
END_VAR

VAR_OUTPUT
    refredament : Bool;          // Sortida de refrigeració (276.0)
    calefaccio : Bool;          // Sortida de calefacció (276.1)
    HMI_TemperaturaActual : Real; // Temperatura actual per HMI (278.0)
    HMI_SetPoint : Real;         // Punt de consigna per HMI (282.0)
    HMI_ModeActual : String;     // Mode actual per HMI (286.0)
    HMI_PercentatgeSortida : Real; // Percentatge sortida per HMI (542.0)
    TemperaturaNodeRED : Real;   // Temperatura per Node-RED
END_VAR

// No necessitem declarar el DB ja que utilitzem les variables de sortida

STATIC
    // Constants del sistema
    TEMP_MIN : Real := 0.0;            // Temperatura mínima (680.0)
    TEMP_MAX : Real := 50.0;           // Temperatura màxima (684.0)
    ZONA_MORTA : Real := 0.3;          // Marge de zona morta (572.0)
    HISTERESI : Real := 1.2;           // Factor d'histèresi (688.0)
    TEMPS_MINIM_CANVI : Time := T#180S; // Temps mínim entre canvis (568.0)
    
    // Variables de control i estat
    ControlActiu : Bool;               // Estat del sistema (14.0)
    ModeFred : Bool := FALSE;          // Mode refrigeració actiu (546.0)
    ModeCalent : Bool := FALSE;        // Mode calefacció actiu (546.1)
    ModeActual : String;               // Mode actual (16.0)
    EstemEnZonaMorta : Bool;           // Control d'histèresi (600.0)
    
    // Variables de temperatura i sensors
    TemperaturaReal : Real;            // Temperatura actual (606.0)
    TemperaturaEscalada : Real;        // Temperatura processada (6.0)
    ValorSensor : Real;                // Valor del sensor (610.0)
    Proporcio : Real;                  // Proporció escalada (548.0)
    
    // Variables de sortida i control
    SortidaPID : Real;                 // Sortida del controlador PID (10.0)
    SortidaEscalada : Real;            // Sortida escalada 0-100% (272.0)
    
    // Timer per canvi de mode
    TimerCanviMode : TON_TIME;         // Timer pel canvi de mode (552.0)
END_STATIC

BEGIN
// BLOC 2: PROCESSAMENT DEL SENSOR
// Lectura i processament del sensor
#ValorSensor := INT_TO_REAL(#sensor_temp_jefe);  // Llegim el valor del potenciòmetre
#Proporcio := #ValorSensor / 27648.0;            // Normalitzem a 0-1
#TemperaturaReal := #Proporcio * (#TEMP_MAX - #TEMP_MIN) + #TEMP_MIN;  // Escalem a 0-50°C
#TemperaturaEscalada := #TemperaturaReal;

// BLOC 3: CONTROL PRINCIPAL
IF NOT #ClimaOn THEN
    // Sistema desactivat - Reset de variables
    #ControlActiu := FALSE;
    #SortidaPID := 0.0;
    #SortidaEscalada := 0.0;
    #ModeFred := FALSE;
    #ModeCalent := FALSE;
    #ModeActual := 'Aturat';
ELSE
    #ControlActiu := TRUE;
END_IF;

// BLOC 4: GESTIÓ DE MODES
IF #ControlActiu THEN
    // Control de temps mínim entre canvis
    #TimerCanviMode(IN := #ModeNodeRED <> #ModeActual,
                    PT := #TEMPS_MINIM_CANVI);
    
    // Canvi de mode amb temporització
    IF #TimerCanviMode.Q THEN
        CASE #ModeNodeRED OF
            'Fred':
                #ModeFred := TRUE;
                #ModeCalent := FALSE;
                #ModeActual := 'Fred';
            'Calent':
                #ModeFred := FALSE;
                #ModeCalent := TRUE;
                #ModeActual := 'Calent';
        END_CASE;
    END_IF;    // BLOC 5: CONTROL PID
    IF #ClimaOn THEN
        // PID Mode Fred
        "Control_temperatura_fred"(
            EN := #ControlActiu AND #BotoFred,    // Activem només quan està en mode fred
            Setpoint := #SetPointNodeRED,
            Input := #TemperaturaEscalada
        );
        
        // PID Mode Calent
        "Control_temperatura_oficina_cap"(
            EN := #ControlActiu AND #BotoCalent,  // Activem només quan està en mode calent
            Setpoint := #SetPointNodeRED,
            Input := #TemperaturaEscalada
        );
        
        // Selecció de la sortida segons el mode actiu
        IF #BotoFred AND NOT #EstemEnZonaMorta THEN
            #SortidaPID := "Control_temperatura_fred".Output;
        ELSIF #BotoCalent AND NOT #EstemEnZonaMorta THEN
            #SortidaPID := "Control_temperatura_oficina_cap".Output;
        END_IF;
        
        // Limitació de la sortida (comuna per ambdós modes)
        IF #SortidaPID < 0.0 THEN
            #SortidaEscalada := 0.0;
        ELSIF #SortidaPID > 100.0 THEN
            #SortidaEscalada := 100.0;
        ELSE
            #SortidaEscalada := #SortidaPID;
        END_IF;
    ELSE
        // Desactivem ambdós PIDs
        "Control_temperatura_fred"(EN := FALSE);
        "Control_temperatura_oficina_cap"(EN := FALSE);
    END_IF;
END_IF;

// BLOC 6: ACTUALITZACIÓ DE SORTIDES
#refredament := #ControlActiu AND #ModeFred AND (#SortidaEscalada > 10.0);
#calefaccio := #ControlActiu AND #ModeCalent AND (#SortidaEscalada > 10.0);

// BLOC 7: ACTUALITZACIÓ DE VARIABLES HMI
#HMI_TemperaturaActual := #TemperaturaReal;
#HMI_SetPoint := #SetPointNodeRED;
#HMI_ModeActual := #ModeActual;
#HMI_PercentatgeSortida := #SortidaEscalada;

// Actualització Node-RED
#TemperaturaNodeRED := #TemperaturaReal;

END_PROGRAM
