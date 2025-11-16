UpBusHK-DataBuilder

The UpBusHK-DataBuilder creates the offline database for the UpBusHK app. It uses publicly available data as listed on data.gov.hk.

1. Bus data
   - Routes
     - Primary reference: The routes available for ETA queries on the ETA API represents the complete set of routes to build.
     - Joint routes: Route operated by two companies ike KMB+CTB, LWB+CTB, etc are merged to create a single route in the database.
     - Fare: Stop-based fares (if available) full fare are supplemented by the Hong Kong Government downloadable data set. 
   - Stops
     - With the exception of KMB stops, a complete set of stops are created using route-stops from the complete set of routes. Then the stops are queried one by one from the API.
     - KMB stops are queried using a single API call.
   - Track
     - The GPS tracks are supplemented by the Hong Kong Government downloadable set and decimated using the Ramer–Douglas–Peucker algorithm.
2. Minibus data
   - Routes
     - Primary reference: The routes available for ETA queries on the ETA API represents the complete set of routes to build.
     - Fare: Full fare only, as supplemented by the Hong Kong Government downloadable data set.
   - Stops
     - A complete set of stops are created using route-stops from the complete set of routes. Then the stops are queried one by one from the API.