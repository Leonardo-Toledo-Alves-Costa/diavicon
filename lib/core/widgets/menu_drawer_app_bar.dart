import 'package:flutter/material.dart';

class MenuDrawerAppBar extends StatelessWidget {
  final String title;
  final List<Widget> items; 

  const MenuDrawerAppBar({
    super.key, 
    required this.title, 
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final maxMenuHeight = MediaQuery.of(context).size.height - 160;
    
    final minMenuHeight = 540.0 < maxMenuHeight ? 540.0 : maxMenuHeight;

    return Drawer(
      width: 130, 
      backgroundColor: Colors.transparent, 
      elevation: 0, 
      child: Align(
        alignment: Alignment.topRight, 
        child: Container(
          margin: const EdgeInsets.only(top: 110, bottom: 40), 
          constraints: BoxConstraints(
            minHeight: minMenuHeight, 
            maxHeight: maxMenuHeight, 
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFEBEBEB), 
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(40)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2), 
                blurRadius: 15,
                offset: const Offset(-2, 4),
              ),
            ],
          ),
          child: SingleChildScrollView( 
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 28, 8, 16),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Color(0xFF4A4A4A), 
                      height: 1.2,
                    ),
                  ),
                ),
                
                ...items,
                
                const SizedBox(height: 16), 
              ],
            ),
          ),
        ),
      ),
    );
  }
}