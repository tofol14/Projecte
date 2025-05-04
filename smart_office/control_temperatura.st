// Variables de zona morta i temperatura
STATIC
    EstemEnZonaMorta : Bool;    // Per controlar la histèresi de la zona morta
    UltimaTemperaturaReal : Real;    // Per detectar canvis en la temperatura del sensor
    TemperaturaReal : Real;    // Per emmagatzemar la temperatura actual del sensor
    ValorSensor : Real;    // Per emmagatzemar el valor raw del sensor
    valor_raw_sensor : Int;    // Per debug del valor directe del sensor
    proporcio_debug : Real;    // Per debug de la proporció normalitzada
    temp_real_debug : Real;    // Per debug de la temperatura real
    setpoint_debug : Real;    // Per debug del setpoint
    temp_entrada_pid : Real;    // Per debug de la temperatura que entra al PID
    setpoint_entrada_pid : Real;    // Per debug del setpoint que entra al PID
    TemperaturaSimulada : Real;    // Per simular la temperatura del sistema
    TempsPID : Time;           // Per controlar el temps entre càlculs
    UltimTemps : Time;         // Per calcular el delta de temps
    DeltaTemps : Real;         // Per emmagatzemar el temps entre càlculs en segons
    ProporcioSimulada : Real;  // Per la conversió de temperatura a valor de sensor
    ValorSensorSimulat : Int;  // Valor simulat del sensor
    TimerSimulacio {InstructionName := 'TON'} : TON;    // Timer per la simulació
    TempsAnterior : Time;    // Per calcular el delta de temps
    TempsActual : Time;      // Temps actual del cicle
    TaxaEscalfament : Real;  // Taxa d'escalfament per la simulació
    TaxaRefredament : Real;  // Taxa de refredament per la simulació
    Proporcio : Real;        // Per la normalització

// 1. PROCESSAMENT DEL SENSOR DE TEMPERATURA
// Inicialització de variables de simulació
IF #TempSimulada = 0.0 THEN
    #TempSimulada := #TempMin;
    #TaxaEscalfament := 0.1;    // Reduïm la taxa per fer-ho més suau
    #TaxaRefredament := 0.05;   // Reduïm la taxa per fer-ho més suau
    #UltimaTemperaturaReal := #TempMin;
    #TemperaturaSimulada := #TempMin;
    #TempsAnterior := T#0MS;
    #TemperaturaEscalada := #TempMin;  // Inicialitzem també la temperatura escalada
END_IF;

// 2. CONTROL PRINCIPAL ON/OFF
IF NOT #ClimaOn THEN
    // Sistema desactivat - Reset de variables
    #ControlActiu := FALSE;
    #SortidaPID := 0.0;
    #SortidaEscalada := 0.0;
    #ModeFred := FALSE;
    #ModeCalent := FALSE;
    #ModeActual := 'OFF';
    // Mantenim la última temperatura quan està apagat
    #TemperaturaEscalada := #TemperaturaSimulada;
ELSE
    #ControlActiu := TRUE;
END_IF;

// 3. ACTUALITZACIÓ DEL TEMPS I SIMULACIÓ
// Actualitzar temps per la simulació utilitzant TON
#TimerSimulacio(IN := TRUE,
                PT := T#1S);  // Actualitzem cada segon

IF #TimerSimulacio.Q THEN
    #TempsActual := #TimerSimulacio.ET;
    
    // Calcular delta de temps (en segons)
    IF #TempsAnterior = T#0MS THEN
        #DeltaTemps := 0.1;  // Valor inicial per evitar pics
    ELSE
        #DeltaTemps := DINT_TO_REAL(TIME_TO_DINT(#TempsActual - #TempsAnterior)) / 1000.0;
    END_IF;
    
    #TempsAnterior := #TempsActual;
    #TimerSimulacio(IN := FALSE,
                    PT := T#1S);  // Reiniciar el timer
END_IF;

// Processar valor del sensor abans de la simulació
#ValorSensor := INT_TO_REAL("sensor_temp_jefe");
#valor_raw_sensor := REAL_TO_INT(#ValorSensor);

// Normalització i escalat del sensor actual
#Proporcio := #ValorSensor / 27648.0;
#TemperaturaReal := #Proporcio * (#TempMax - #TempMin) + #TempMin;

// Simulació del comportament tèrmic sempre activa
IF #ControlActiu THEN
    IF #ModeFred THEN
        // Mode refrigeració - La sortida del PID refreda
        #TemperaturaSimulada := #TemperaturaSimulada - (#SortidaEscalada * #TaxaEscalfament * #DeltaTemps);
    ELSE
        // Mode calefacció - La sortida del PID escalfa
        #TemperaturaSimulada := #TemperaturaSimulada + (#SortidaEscalada * #TaxaEscalfament * #DeltaTemps);
    END_IF;
    
    // Simular pèrdua natural de temperatura
    IF #TemperaturaSimulada > #TempMin THEN
        #TemperaturaSimulada := #TemperaturaSimulada - (#TaxaRefredament * #DeltaTemps);
    END_IF;
    
    // Limitar la temperatura simulada
    IF #TemperaturaSimulada < #TempMin THEN
        #TemperaturaSimulada := #TempMin;
    ELSIF #TemperaturaSimulada > #TempMax THEN
        #TemperaturaSimulada := #TempMax;
    END_IF;
    
    // Actualitzar temperatura escalada amb la simulada
    #TemperaturaEscalada := #TemperaturaSimulada;
    
    // Convertir temperatura simulada a format sensor (0-27648)
    #ProporcioSimulada := (#TemperaturaSimulada - #TempMin) / (#TempMax - #TempMin);
    #ValorSensorSimulat := REAL_TO_INT(#ProporcioSimulada * 27648.0);
    
    // Assignar al tag del sensor
    "sensor_temp_jefe" := #ValorSensorSimulat;
END_IF;

// Debug dels valors - Actualitzem sempre
#proporcio_debug := #ProporcioSimulada;
#temp_real_debug := #TemperaturaSimulada;
#setpoint_debug := #SetPointNodeRED;
#temp_entrada_pid := #TemperaturaEscalada;
#setpoint_entrada_pid := #SetPointNodeRED;

// 3. GESTIÓ DE MODES AMB TEMPORITZACIÓ
IF #ControlActiu THEN
    // Control de temps mínim entre canvis
    #TimerCanviMode(IN := #BotoFred OR #BotoCalent,
                    PT := #TEMPS_MINIM_CANVI);
    
    // Canvi de mode amb temporització
    IF #TimerCanviMode.Q THEN
        IF #BotoFred AND NOT #BotoCalent AND NOT #ModeFred THEN
            // Activació mode fred
            #ModeFred := TRUE;
            #ModeCalent := FALSE;
            #ModeActual := 'Fred';
        ELSIF #BotoCalent AND NOT #BotoFred AND NOT #ModeCalent THEN
            // Activació mode calent
            #ModeFred := FALSE;
            #ModeCalent := TRUE;
            #ModeActual := 'Calent';
        END_IF;
    END_IF;
    
    // 4. CONTROL PID I SORTIDA
    // Validació inicial del SetPoint
    IF #SetPointNodeRED < #TempMin THEN
        #SetPointNodeRED := #TempMin;
    ELSIF #SetPointNodeRED > #TempMax THEN
        #SetPointNodeRED := #TempMax;
    END_IF;
    
    // Assignació directa al PID
    "Control_temperatura_oficina_cap".Setpoint := #SetPointNodeRED;
    "Control_temperatura_oficina_cap".Input := #TemperaturaEscalada;
    
    // Control de zona morta amb histèresi
    IF ABS(#TemperaturaEscalada - #SetPointNodeRED) <= #ZONA_MORTA THEN
        #SortidaPID := 0.0;
        #EstemEnZonaMorta := TRUE;
    ELSIF ABS(#TemperaturaEscalada - #SetPointNodeRED) >= (#ZONA_MORTA * 1.2) THEN
        #EstemEnZonaMorta := FALSE;
    END_IF;
    
    IF NOT #EstemEnZonaMorta THEN
        // Execució del PID
        "Control_temperatura_oficina_cap"();
        
        // Processar sortida del PID
        #SortidaPID := "Control_temperatura_oficina_cap".Output;
        
        // Gestió mode fred
        IF #ModeFred THEN
            #SortidaPID := -#SortidaPID;
        END_IF;
        
        // Limitació de la sortida amb més granularitat
        IF #SortidaPID < 0.0 THEN
            #SortidaEscalada := 0.0;
        ELSIF #SortidaPID > 100.0 THEN
            #SortidaEscalada := 100.0;
        ELSE
            #SortidaEscalada := #SortidaPID;
        END_IF;
    END_IF;
END_IF;

