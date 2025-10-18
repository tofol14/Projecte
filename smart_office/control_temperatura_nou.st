// BLOC 1: INICIALITZACIÓ I DEFINICIÓ DE VARIABLES
VAR_INPUT
    SetPointNodeRED : Real;  // Punt de consigna rebut de Node-RED
    sensor_temp_jefe : Int;  // Entrada del sensor de Factory IO (%IW40)
    temperatura_cap_DB : "temperatura_cap_DB";  // Referència al DB
    BotoFred : Bool;         // Botó per activar mode refrigeració
    BotoCalent : Bool;       // Botó per activar mode calefacció
    ClimaOn : Bool;         // Interruptor principal del sistema
END_VAR

VAR_OUTPUT
    TemperaturaNodeRED : Real;  // Temperatura en graus per Node-RED
    refredament : Bool;         // Sortida de refrigeració
    calefaccio : Bool;         // Sortida de calefacció
END_VAR

STATIC
    // Constants del sistema
    TEMP_MIN : Real := 0.0;           // Temperatura mínima permesa
    TEMP_MAX : Real := 50.0;          // Temperatura màxima permesa
    ZONA_MORTA : Real := 0.3;         // Marge de zona morta pel control
    HISTERESI : Real := 1.2;          // Factor d'histèresi
    TEMPS_MINIM_CANVI : Time := T#180S; // Temps mínim entre canvis de mode
    
    // Variables de control i estat
    EstemEnZonaMorta : Bool;          // Control d'histèresi
    ControlActiu : Bool;              // Estat del sistema
    ModeFred : Bool := FALSE;         // Mode refrigeració actiu
    ModeCalent : Bool := FALSE;       // Mode calefacció actiu
    ModeActual : String;              // Mode actual en text
    
    // Variables de temperatura i sensors
    TemperaturaReal : Real;           // Temperatura actual
    TemperaturaEscalada : Real;       // Temperatura processada
    ValorSensor : Real;               // Valor del sensor
    Proporcio : Real;                 // Proporció escalada del sensor
    
    // Variables de sortida i control
    SortidaPID : Real;                // Sortida del controlador PID
    SortidaEscalada : Real;           // Sortida escalada (0-100%)
    
    // Variables HMI/Monitorització
    HMI_TemperaturaActual : Real;     // Temperatura actual per HMI
    HMI_SetPoint : Real;              // Punt de consigna actual per HMI
    HMI_ModeActual : String;          // Mode de funcionament per HMI
    HMI_PercentatgeSortida : Real;    // Percentatge sortida per HMI
END_VAR

BEGIN
// BLOC 2: PROCESSAMENT DEL SENSOR
// Lectura i processament del sensor
#ValorSensor := INT_TO_REAL("sensor_temp_jefe");  // Llegim el valor del potenciòmetre
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
    #TimerCanviMode(IN := #BotoFred OR #BotoCalent,
                    PT := #TEMPS_MINIM_CANVI);
    
    // Canvi de mode amb temporització
    IF #TimerCanviMode.Q THEN
        IF #BotoFred AND NOT #BotoCalent THEN
            #ModeFred := TRUE;
            #ModeCalent := FALSE;
            #ModeActual := 'Fred';
        ELSIF #BotoCalent AND NOT #BotoFred THEN
            #ModeFred := FALSE;
            #ModeCalent := TRUE;
            #ModeActual := 'Calent';
        END_IF;
    END_IF;
    
    // BLOC 5: CONTROL PID
    IF #ClimaOn THEN
        "Control_temperatura_oficina_cap"(
            EN := #ControlActiu,
            Setpoint := #SetPointNodeRED,
            Input := #TemperaturaEscalada
        );
        
        IF NOT #EstemEnZonaMorta THEN
            #SortidaPID := "Control_temperatura_oficina_cap".Output;
            
            // Inversió de sortida per mode fred
            IF #ModeFred THEN
                #SortidaPID := -#SortidaPID;
            END_IF;
            
            // Limitació de la sortida
            IF #SortidaPID < 0.0 THEN
                #SortidaEscalada := 0.0;
            ELSIF #SortidaPID > 100.0 THEN
                #SortidaEscalada := 100.0;
            ELSE
                #SortidaEscalada := #SortidaPID;
            END_IF;
        END_IF;
    ELSE
        "Control_temperatura_oficina_cap"(EN := FALSE);
    END_IF;
END_IF;

// BLOC 6: ACTUALITZACIÓ DE SORTIDES
#refredament := #ControlActiu AND #ModeFred AND (#SortidaEscalada > 10.0);
#calefaccio := #ControlActiu AND #ModeCalent AND (#SortidaEscalada > 10.0);

// BLOC 7: ACTUALITZACIÓ DE VARIABLES HMI I DB
#HMI_TemperaturaActual := #TemperaturaReal;
#HMI_SetPoint := #SetPointNodeRED;
#HMI_ModeActual := #ModeActual;
#HMI_PercentatgeSortida := #SortidaEscalada;

// Actualitzacions DB
#temperatura_cap_DB.TemperaturaEscalada := #TemperaturaEscalada;
#temperatura_cap_DB.HMI_TemperaturaActual := #TemperaturaReal;
#temperatura_cap_DB.HMI_SetPoint := #SetPointNodeRED;

// Actualització Node-RED
#TemperaturaNodeRED := #TemperaturaReal;

END_PROGRAM
