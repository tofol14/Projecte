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
    #TimerCanviMode(IN := (#BotoFred AND NOT #ModeFred) OR (#BotoCalent AND NOT #ModeCalent),
                    PT := #TEMPS_MINIM_CANVI);
    
    // Actualització de modes amb temporització
    IF #TimerCanviMode.Q THEN
        #ModeFred := #BotoFred AND NOT #BotoCalent;
        #ModeCalent := #BotoCalent AND NOT #BotoFred;
        
        IF #ModeFred THEN
            #ModeActual := 'Fred';
        ELSIF #ModeCalent THEN
            #ModeActual := 'Calent';
        ELSE
            #ModeActual := 'Aturat';
        END_IF;
    END_IF;    
    
    // BLOC 5: CONTROL PID
    IF #ClimaOn THEN
        // PID Mode Fred
        "Control_temperatura_fred"(
            EN := #ControlActiu AND #ModeFred,  // Cambiado de BotoFred a ModeFred
            ManualEnable := FALSE,
            Reset := FALSE,
            Setpoint := #SetPointNodeRED,
            Input := #TemperaturaEscalada,
            ManualValue := 0.0
        );
        
        // PID Mode Calent
        "Control_temperatura_calent"(
            EN := #ControlActiu AND #ModeCalent,  // Cambiado de BotoCalent a ModeCalent
            ManualEnable := FALSE,
            Reset := FALSE,
            Setpoint := #SetPointNodeRED,
            Input := #TemperaturaEscalada,
            ManualValue := 0.0
        );
        
        // Actualitzar zona morta
        #EstemEnZonaMorta := ABS(#SetPointNodeRED - #TemperaturaEscalada) < #ZONA_MORTA;
        
        // Selecció de la sortida segons el mode actiu
        IF #ModeFred AND NOT #EstemEnZonaMorta THEN  // Cambiado de BotoFred a ModeFred
            #SortidaPID := "Control_temperatura_fred".Output;
        ELSIF #ModeCalent AND NOT #EstemEnZonaMorta THEN  // Cambiado de BotoCalent a ModeCalent
            #SortidaPID := "Control_temperatura_calent".Output;
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
        // Desactivem ambdós PIDs i els posem en mode manual
        "Control_temperatura_fred"(
            EN := FALSE,
            ManualEnable := TRUE,
            Reset := TRUE,
            Setpoint := 0.0,
            Input := 0.0,
            ManualValue := 0.0
        );
        
        "Control_temperatura_calent"(
            EN := FALSE,
            ManualEnable := TRUE,
            Reset := TRUE,
            Setpoint := 0.0,
            Input := 0.0,
            ManualValue := 0.0
        );
    END_IF;
END_IF;

// BLOC 6: ACTUALITZACIÓ DE SORTIDES
#refredament := #ControlActiu AND #ModeFred;  // En simulació, activem directament amb el mode
#calefaccio := #ControlActiu AND #ModeCalent;  // En simulació, activem directament amb el mode

// BLOC 7: ACTUALITZACIÓ DE VARIABLES HMI
#HMI_TemperaturaActual := #TemperaturaReal;
#HMI_SetPoint := #SetPointNodeRED;
#HMI_ModeActual := #ModeActual;
#HMI_PercentatgeSortida := #SortidaEscalada;

// Actualització Node-RED
#TemperaturaNodeRED := #TemperaturaReal;

END_PROGRAM
