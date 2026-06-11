//
//  DataController.swift
//  bib-app
//
//  Created by Daniel Schäfer / PBD2H24A on 11.06.26.
//


import Foundation
import CoreData
class DataController  {
    let container:NSPersistentContainer
    let viewContext : NSManagedObjectContext
    init() {
        container=NSPersistentContainer(name:"Model")
        container.loadPersistentStores(completionHandler: {description,error in
            if  error != nil {
                fatalError("Error: \(error!.localizedDescription)")
            }
        })
        viewContext=container.viewContext
    }
    
    // Neue Fächer erzeugen:
    
    func neuesPokemon(name:String, url:URL)-> Pokemon{
        let pokemon = Pokemon(context: viewContext)
        pokemon.nme = name
        pokemon.url = url
        return pokemon
    }
    
    
    
    //Fach löschen)
    func loeschen(pokemon: Pokemon)
        {
            viewContext.delete(pokemon)
            
        }

    // Objekte auslesen:
    
    var pokemons : [Pokemon] {
            let request : NSFetchRequest<Pokemon> = Pokemon.fetchRequest()
            //Um auf die Property Values zugreifen zu können:
            request.returnsObjectsAsFaults=false
            let pokemon = try! viewContext.fetch(request)
            return pokemon
        }
    
    
    
    // Objekte auslesen mit Selektion:
    
        public func pokemonArray(nme: String) -> [Pokemon]{
            let request : NSFetchRequest<Pokemon> = Pokemon.fetchRequest()
            request.predicate = NSPredicate(format: "name == %@", nme)
            let pokemon = try! viewContext.fetch(request).sorted(by: {
                return $0.nme! < $1.nme!
            })
            return pokemon
        }
    
    // Objekte ändern:
    
    /*Es können ganz einfach die Properties neu gesetzt werden. Dadurch ändern sich die Objekte im viewContext. Es wird also eigentlich keine Methode benötigt.*/
    
    // Objekte des viewContext in die Datenbank schreiben:
    /*Erst wenn dem  viewContext die Nachricht save: geschickt wird, werden die Änderungen dauerhaft in der DB übernommen:*/
        
        func save () {
                assert (Thread.isMainThread)
                do {
                    try self.viewContext.save()
                                 }
                catch let error {
                    print("Fehler beim Speichern: \(error)")
                }
        
            }
}
